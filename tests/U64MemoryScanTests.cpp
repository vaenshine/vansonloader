// Exercises the real scanner against synthetic Mach regions on macOS.
#include "../src/Core/VLMemCore.hpp"
#include <algorithm>
#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>
#include <unistd.h>
#include <vector>

using vcore::MemCore;
using vcore::MemDataType;
using vcore::ScanResult;
static constexpr uint64_t kBase = 0x145966000ULL;
static constexpr size_t kChunk = 1024 * 1024;
static constexpr uint64_t kValue = 4114578669569ULL;
struct Region { uint64_t base; std::vector<uint8_t> bytes; bool writable = true; };
static std::vector<Region> regions;
static std::atomic<size_t> invalidReads{0}, maxRead{0};
static size_t shortReadLimit = SIZE_MAX;
static size_t checks = 0;

static void check(bool condition, const char* message) {
    ++checks;
    if (!condition) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}

extern "C" kern_return_t mach_vm_region_recurse(vm_map_t, mach_vm_address_t* address,
    mach_vm_size_t* size, uint32_t*, vm_region_recurse_info_t rawInfo,
    mach_msg_type_number_t*) {
    for (const auto& region : regions) {
        if (*address >= region.base + region.bytes.size()) continue;
        *address = region.base;
        *size = region.bytes.size();
        auto info = reinterpret_cast<vm_region_submap_info_data_64_t*>(rawInfo);
        std::memset(info, 0, sizeof(*info));
        info->protection = VM_PROT_READ | (region.writable ? VM_PROT_WRITE : 0);
        return KERN_SUCCESS;
    }
    return KERN_INVALID_ADDRESS;
}

extern "C" kern_return_t mach_vm_read_overwrite(vm_map_t, mach_vm_address_t address,
    mach_vm_size_t size, mach_vm_address_t data, mach_vm_size_t* outSize) {
    size_t previous = maxRead.load();
    while (previous < size && !maxRead.compare_exchange_weak(previous, size)) {}
    *outSize = 0;
    for (const auto& region : regions) {
        if (address < region.base || address - region.base >= region.bytes.size()) continue;
        size_t offset = address - region.base;
        if (size > region.bytes.size() - offset) break;
        size_t returned = std::min((size_t)size, shortReadLimit);
        std::memcpy(reinterpret_cast<void*>(data), region.bytes.data() + offset, returned);
        *outSize = returned;
        return KERN_SUCCESS;
    }
    ++invalidReads;
    return KERN_INVALID_ADDRESS;
}

static void reset(size_t size) {
    regions = {{kBase, std::vector<uint8_t>(size, 0xA5), true}};
    invalidReads = 0;
    maxRead = 0;
    shortReadLimit = SIZE_MAX;
}

template <typename T> static void put(size_t offset, T value) {
    check(offset <= regions[0].bytes.size() && sizeof(value) <= regions[0].bytes.size() - offset,
          "fixture write is inside its region");
    std::memcpy(regions[0].bytes.data() + offset, &value, sizeof(value));
}

static std::vector<ScanResult> scan(MemCore& core, MemDataType type,
    const std::string& value, int mode = 0, size_t from = 0, size_t through = SIZE_MAX) {
    uint64_t end = through == SIZE_MAX ? regions.back().base + regions.back().bytes.size() : kBase + through;
    core.scan(type, value, mode, kBase + from, end);
    auto results = core.getResults(0, core.getResultCount());
    check(results.size() == core.getResultCount(), "result count agrees with result file");
    check(invalidReads == 0, "scanner never reads outside readable region");
    size_t allowedRead = kChunk + (type == MemDataType::String ? std::max((size_t)7, value.size() - 1) : 7);
    check(maxRead <= allowedRead, "scan reads remain bounded regardless of group range");
    return results;
}

static void expectAddresses(const std::vector<ScanResult>& results,
                            std::vector<size_t> offsets, const char* name) {
    std::vector<uint64_t> actual, expected;
    for (auto result : results) actual.push_back(result.address);
    for (auto offset : offsets) expected.push_back(kBase + offset);
    std::sort(actual.begin(), actual.end());
    std::sort(expected.begin(), expected.end());
    if (actual != expected) {
        std::fprintf(stderr, "%s: expected %zu rows, got %zu\n", name, expected.size(), actual.size());
        for (auto address : actual) std::fprintf(stderr, "  actual 0x%llx\n", address);
    }
    check(actual == expected, name);
    check(std::adjacent_find(actual.begin(), actual.end()) == actual.end(), "candidate addresses are unique");
}

int main(int argc, char** argv) {
    check(argc == 2, "temporary output directory provided");
    MemCore core;
    core.init();
    std::string output = std::string(argv[1]) + "/results.bin";
    core.setStoragePath(output, output + ".swap");
    const std::string target = std::to_string(kValue);

    reset(4096);
    std::vector<size_t> offsets;
    for (size_t i = 0; i < 8; ++i) { size_t offset = 0xA0 + i * 32 + i; put(offset, kValue); offsets.push_back(offset); }
    auto results = scan(core, MemDataType::UInt64, target);
    expectAddresses(results, offsets, "U64 includes all eight address residues");
    for (const auto& result : results) check(result.value.u64 == kValue, "U64 retains all eight value bytes");
    expectAddresses(core.nextScan(MemDataType::UInt64, target, 100), offsets, "exact rescan retains unaligned U64");
    put(offsets[3], kValue + 1);
    offsets.erase(offsets.begin() + 3);
    expectAddresses(core.nextScan(MemDataType::UInt64, target, 100), offsets, "rescan removes changed value");
    expectAddresses(scan(core, MemDataType::Int64, target), offsets, "I64 includes every byte offset");

    reset(8192);
    put(4093, kValue);
    expectAddresses(scan(core, MemDataType::UInt64, target), {4093}, "U64 crosses a page boundary");

    for (size_t tail = 1; tail <= 7; ++tail) {
        reset(kChunk + 64);
        put(kChunk - tail, kValue);
        put(kChunk + 32, kValue);
        expectAddresses(scan(core, MemDataType::UInt64, target), {kChunk - tail, kChunk + 32}, "every crossing of a 1 MiB chunk");
        expectAddresses(scan(core, MemDataType::UInt64, target + "," + target, 3), {kChunk - tail, kChunk + 32}, "U64 range covers chunk boundary");
    }
    reset(kChunk + 7);
    put(kChunk - 1, kValue);
    expectAddresses(scan(core, MemDataType::UInt64, target), {kChunk - 1}, "last complete value and short final chunk");
    for (size_t size = 1; size < 8; ++size) {
        reset(size);
        expectAddresses(scan(core, MemDataType::UInt64, "0"), {}, "region shorter than U64 has no candidate");
    }
    reset(8); put(0, kValue);
    expectAddresses(scan(core, MemDataType::UInt64, target), {0}, "exactly eight bytes form one candidate");

    reset(512);
    put(97, kValue); put(120, kValue); put(200, kValue);
    expectAddresses(scan(core, MemDataType::UInt64, target, 0, 110, 208), {120, 200}, "clip containing region to requested start/end");
    expectAddresses(scan(core, MemDataType::UInt64, target, 0, 120, 128), {120}, "range precisely encloses a value");
    expectAddresses(scan(core, MemDataType::UInt64, target, 0, 120, 127), {}, "value cannot extend beyond requested end");
    expectAddresses(scan(core, MemDataType::UInt64, target, 0, 208, 208), {}, "empty range has no candidates");

    reset(256);
    constexpr uint64_t high = 0xFEDC123456789ABCULL;
    put(3, high); put(35, high + 1); put(67, high & 0xFFFFFFFFFFFFULL);
    expectAddresses(scan(core, MemDataType::UInt64, std::to_string(high)), {3}, "full unsigned U64 exact comparison above INT64_MAX");
    expectAddresses(core.nextScan(MemDataType::UInt64, std::to_string(high), 100), {3}, "high U64 exact rescan remains bit-exact");
    expectAddresses(scan(core, MemDataType::UInt64, std::to_string(high) + "," + std::to_string(high + 1), 3), {3, 35}, "high U64 range uses unsigned ordering");
    put(99, UINT64_MAX);
    expectAddresses(scan(core, MemDataType::UInt64, std::to_string(UINT64_MAX)), {99}, "UINT64_MAX is parsed and compared exactly");

    reset(256);
    put<int64_t>(3, -2); put<int64_t>(35, 2); put<int64_t>(67, -3); put<int64_t>(99, 3);
    expectAddresses(scan(core, MemDataType::Int64, "-2"), {3}, "negative I64 exact match");
    expectAddresses(scan(core, MemDataType::Int64, "-2,2", 3), {3, 35}, "I64 range spanning zero uses signed ordering");

    reset(128); put(4, kValue);
    shortReadLimit = 7;
    expectAddresses(scan(core, MemDataType::UInt64, target), {}, "successful short initial read cannot form U64");
    shortReadLimit = SIZE_MAX;
    scan(core, MemDataType::UInt64, target);
    shortReadLimit = 7;
    expectAddresses(core.nextScan(MemDataType::UInt64, target, 100), {}, "successful short rescan read is rejected");

    reset(kChunk + 256);
    put(kChunk - 5, kValue); put<uint32_t>(kChunk + 40, 123456789);
    std::string group = target + " u64;123456789 u32::128";
    expectAddresses(scan(core, MemDataType::UInt64, group, 2), {kChunk - 5, kChunk + 40}, "ordered U64 group crosses chunk boundary");
    expectAddresses(scan(core, MemDataType::Int32, group, 2), {kChunk - 5, kChunk + 40}, "explicit U64 group anchor overrides default I32 alignment");
    expectAddresses(scan(core, MemDataType::UInt64, group, 2, 0, kChunk + 42), {}, "group peer must fit in requested range");
    expectAddresses(scan(core, MemDataType::Int64, target + " i64;123456789 u32::128", 2), {kChunk - 5, kChunk + 40}, "I64 first group element crosses boundary");
    reset(kChunk + 256);
    put(kChunk + 5, kValue); put<uint32_t>(kChunk - 40, 123456789);
    core.setGroupAnchorMode(true);
    expectAddresses(scan(core, MemDataType::UInt64, group, 2), {kChunk - 40, kChunk + 5}, "anchor U64 group reads back across chunk");
    core.setGroupAnchorMode(false);
    reset(kChunk + 256);
    put(kChunk - 3, kValue); put<uint32_t>(kChunk + 16, 123456789);
    expectAddresses(scan(core, MemDataType::UInt64, target + " u64;w:11;123456789 u32", 2), {kChunk - 3, kChunk + 16}, "layout U64 group crosses chunk with skip");
    reset(kChunk + 256);
    put(kChunk - 3, kValue); put<uint32_t>(kChunk + 9, 123456789);
    expectAddresses(scan(core, MemDataType::UInt64, target + " u64;? u32;123456789 u32", 2), {kChunk - 3, kChunk + 9}, "layout wildcard group reads across chunk");

    reset(kChunk * 2 + 256);
    put(3, kValue); put<uint32_t>(kChunk + 33, 123456789);
    expectAddresses(scan(core, MemDataType::UInt64, target + " u64;123456789 u32::18446744073709551615", 2), {3, kChunk + 33}, "huge group range uses bounded reader and safe arithmetic");
    reset(kChunk + 128);
    put(kChunk - 3, high); put<uint32_t>(kChunk + 33, 123456789);
    expectAddresses(scan(core, MemDataType::UInt64, std::to_string(high) + " u64;123456789 u32::128", 2), {kChunk - 3, kChunk + 33}, "group comparison preserves unsigned high bits");
    reset(kChunk + 128);
    put(kChunk - 3, kValue);
    expectAddresses(scan(core, MemDataType::UInt64, target + " u64;w:18446744073709551615;123456789 u32", 2), {}, "overflowing layout skip safely fails");

    // A value split across distinct Mach regions is outside either readable scan window.
    reset(16);
    regions.push_back({kBase + 16, std::vector<uint8_t>(16, 0xA5), true});
    std::memcpy(regions[0].bytes.data() + 13, &kValue, 3);
    std::memcpy(regions[1].bytes.data(), reinterpret_cast<const uint8_t*>(&kValue) + 3, 5);
    expectAddresses(scan(core, MemDataType::UInt64, target), {}, "scan never joins separate memory regions");

    reset(256); put<uint32_t>(4, 123456789); put<uint32_t>(17, 123456789);
    expectAddresses(scan(core, MemDataType::Int32, "123456789"), {4}, "I32 keeps its four-byte stepping");
    expectAddresses(scan(core, MemDataType::UInt32, "123456789"), {4}, "U32 keeps its four-byte stepping");
    reset(256); put<float>(4, 1234.5f); put<float>(17, 1234.5f);
    expectAddresses(scan(core, MemDataType::Float, "1234.5"), {4}, "F32 keeps its four-byte stepping");
    reset(256); put<double>(8, 1234.5); put<double>(33, 1234.5);
    expectAddresses(scan(core, MemDataType::Double, "1234.5"), {8}, "F64 keeps its eight-byte stepping");
    reset(kChunk + 64);
    const char text[] = "AtlasDemo";
    std::memcpy(regions[0].bytes.data() + kChunk - 3, text, sizeof(text) - 1);
    expectAddresses(scan(core, MemDataType::String, text), {kChunk - 3}, "string comparison still supports arbitrary bytes");

    std::printf("PASS: %zu checks against production VLMemCore.cpp\n", checks);
}
