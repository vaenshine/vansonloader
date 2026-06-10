/**
 * VansonLoader - 한국어 언어 팩
 */

#include <map>
#include <string>

std::map<std::string, std::string> getLangKO() {
    return {
        // 탭 라벨
        {"Tab_Ptr", "포인터"},
        {"Tab_RVA", "RVA"},
        {"Tab_Sig", "시그니처"},
        {"Tab_Search", "메모리"},
        {"Tab_Tool", "도구"},
        {"Tab_Assist", "보조"},
        {"Tab_Window", "창"},
        {"Tab_About", "정보"},
        {"Tab_Mem", "메모리"},
        {"Tab_Fav", "즐겨찾기"},
        {"Tab_Script", "스크립트"},
        {"Tab_Watch", "감시"},
        {"Tab_MemBrowser", "브라우저"},
        {"Tab_Lock", "잠금"},
        {"Btn_Back", "뒤로"},

        // 버튼
        {"Btn_Modify", "수정"},
        {"Btn_Refresh", "새로고침"},
        {"Btn_View", "보기"},
        {"Btn_Search", "검색"},
        {"Btn_Scan", "매치"},
        {"Btn_Cancel", "취소"},
        {"Btn_Close", "닫기"},
        {"Btn_OK", "확인"},
        {"Btn_Edit", "편집"},
        {"Btn_Delete", "삭제"},
        {"Btn_Done", "완료"},

        // 패널 크기
        {"Size_Small", "소"},
        {"Size_Medium", "중"},
        {"Size_Large", "대"},

        // 도구 페이지
        {"Tool_Clicker", "자동 클리커"},
        {"Tool_Dump", "데이터 내보내기"},
        {"Tool_Config", "설정"},

        // 빈 상태
        {"Empty_Ptr", "포인터 설정 없음"},
        {"Empty_RVA", "RVA 설정 없음"},
        {"Empty_Sig", "시그니처 설정 없음"},
        {"Empty_Hint", "도구 -> 설정 가져오기"},
        {"Empty_Mem", "검색 결과 없음"},
        {"Empty_Mem_Hint", "플로팅 버튼으로 검색"},
        {"Empty_Fav", "즐겨찾기 없음"},
        {"Empty_Fav_Hint", "메모리 결과에서 추가"},
        {"Empty_Script", "스크립트 없음"},
        {"Empty_Script_Hint", ".vmsc 파일 가져오기"},

        // 설정 관리
        {"Config_Import", "설정 가져오기"},
        {"Config_Delete", "설정 삭제"},
        {"Config_DeleteConfirm", "현재 설정을 삭제하고 메뉴를 지우시겠습니까?"},
        {"Config_Deleted", "설정 삭제됨"},
        {"Config_ImportSuccess", "가져오기 완료"},
        {"Config_ImportError", "형식 오류 또는 복호화 실패"},

        // 클리커
        {"Click_AddPt", "포인트 추가"},
        {"Click_Undo", "실행 취소"},
        {"Click_Start", "시작"},
        {"Click_Stop", "중지"},
        {"Click_NoPoints", "먼저 포인트를 추가하세요"},
        {"Click_Freq", "빈도:"},
        {"Click_Points", "포인트:"},

        // Dump
        {"Dump_Btn", "Unity Metadata + Binary 덤프"},

        // RVA 경고
        {"RVA_Warning", "탈옥 기기 전용"},

        // 정보 페이지
        {"About_Title", "VansonLoader"},
        {"About_Telegram", "Telegram @VansonMod"},
        {"About_Lang", "Languages"},
        {"About_Disclaimer", "면책 조항"},
        {"Disclaimer_Agreed", "면책 조항 동의함"},
        {"Disclaimer_Tap", "탭하여 보기"},
        {"Disclaimer_Agree", "동의"},
        {"Disclaimer_Reject", "거부"},
        {"Disclaimer_Rejected", "거부됨, 종료 중..."},
        {"Disclaimer_Exit", "종료"},
        {"Disclaimer_Text", "・This project is open source under GPL-3.0 and is intended for security research, reverse engineering learning, and compliant testing.\n\n・Use it in lawful environments and respect applicable rules for target apps and systems.\n\n・Operational risks and legal responsibilities from use are borne by the user."},
        {"Disclaimer_Content", "・This project is open source under GPL-3.0 and is intended for security research, reverse engineering learning, and compliant testing.\n\n・Use it in lawful environments and respect applicable rules for target apps and systems.\n\n・Operational risks and legal responsibilities from use are borne by the user."},

        // 토스트 메시지
        {"Msg_ImportSuccess", "가져오기 완료"},
        {"Msg_ImportError", "형식 오류"},
        {"Msg_Locked", "잠김"},
        {"Msg_Unlocked", "잠금 해제"},
        {"Msg_Patched", "패치됨"},
        {"Msg_Restored", "복원됨"},
        {"Msg_WriteFail", "쓰기 실패"},
        {"Msg_ModuleNotFound", "모듈을 찾을 수 없음"},
        {"Msg_Scanning", "스캔 중..."},
        {"Msg_ScanComplete", "스캔 완료"},
        {"Msg_NoResult", "결과 없음"},
        {"Msg_Saved", "저장됨"},
        {"Msg_LangChanged", "언어가 변경되었습니다"},
        {"Msg_Matched", "매치 성공"},
        {"Msg_MultiMatch", "개 매치"},
        {"Msg_UniqueMatch", "고유 매치"},
        {"Msg_ClickToScan", "매치 버튼을 클릭하여 검색"},
        {"Msg_WriteFailed", "쓰기 실패"},
        {"Msg_MoreMatches", "+%lu 개"},

        // 셀 정보
        {"Cell_RVA", "RVA: 0x%llX"},
        {"Cell_Unnamed", "이름 없음"},
        {"Cell_Result", "결과"},

        // 시그니처
        {"Sig_Addr", "주소"},

        // 알림
        {"Alert_Cancel", "취소"},
        {"Alert_Confirm", "확인"},
        {"Alert_Current", "현재 값: %@"},

        // 편집기
        {"Edit_Title", "항목 편집"},
        {"Edit_Save", "저장"},
        {"Edit_Section_Basic", "기본 정보"},
        {"Edit_Section_UI", "UI 모드"},
        {"Edit_Section_Slider", "슬라이더 설정"},
        {"Edit_Section_Switch", "스위치 설정"},
        {"Edit_Note", "메모"},
        {"Edit_Value", "값"},
        {"Edit_UIMode", "UI 모드"},
        {"Edit_DataType", "데이터 유형"},
        {"Edit_Author", "작성자"},
        {"Edit_Min", "최소값"},
        {"Edit_Max", "최대값"},
        {"Edit_OnValue", "ON 값"},
        {"Edit_OffValue", "OFF 값"},
        {"Edit_Section_RVA", "RVA 패치"},
        {"Edit_Module", "프레임워크"},
        {"Edit_Offset", "오프셋"},
        {"Edit_PatchHex", "패치 HEX"},
        {"Edit_OrigHex", "원본 HEX"},

        // UI 모드
        {"Mode_Card", "카드"},
        {"Mode_Slider", "슬라이더"},
        {"Mode_Switch", "스위치"},
        {"About_Version", "버전 %@"},
        {"About_License", "v3.1: Search Timeline, Snapshot Restore, Write Undo\nOpen Source: GPL-3.0"},

        // 메모리 검색
        {"Mem_Title", "메모리 검색"},
        {"Mem_Debug_Title", "메모리 디버그"},
        {"Mem_OpenSearch", "메모리 디버그 열기"},
        {"Mem_Status", "검색 상태"},
        {"Mem_NoResults", "결과 없음"},
        {"Mem_Exact", "정확"},
        {"Mem_Fuzzy", "퍼지"},
        {"Mem_Range", "범위"},
        {"Mem_InputValue", "검색 값 입력"},
        {"Mem_Search", "검색"},
        {"Mem_Next", "다음"},
        {"Mem_Reset", "초기화"},
        {"Mem_Ready", "준비"},
        {"Mem_Empty", "결과 없음"},
        {"Mem_Searching", "검색 중..."},
        {"Mem_Filtering", "필터링 중..."},
        {"Mem_Found", "찾음"},
        {"Mem_InputRequired", "값을 입력하세요"},
        {"Mem_LoadMore", "더 불러오기"},
        {"Mem_NoMore", "더 이상 없음"},
        {"Mem_NewValue", "새 값"},
        {"Mem_Write", "쓰기"},
        {"Mem_WriteOK", "쓰기 성공"},
        {"Mem_WriteFail", "쓰기 실패"},
        {"Mem_Browser", "브라우저"},
        {"Mem_Hex", "Hex"},
        {"Mem_Settings", "설정"},
        {"Mem_FloatTol", "부동소수점 허용오차"},
        {"Mem_GroupRange", "그룹 범위"},
        {"Mem_TakingSnapshot", "스냅샷 생성 중..."},
        {"Mem_Snapshot_Ready", "스냅샷 준비 완료, 주소 수"},
        {"Mem_Error", "작업 실패"},
        {"Mem_FloatDebug", "플로팅 메모리 디버그"},
        {"Mem_FloatDebug_On", "활성화"},
        {"Mem_FloatDebug_Off", "비활성화"},
        {"Mem_AddFav", "즐겨찾기에 추가"},
        {"Mem_AddedFav", "즐겨찾기에 추가됨"},
        {"Mem_AlreadyFav", "이미 즐겨찾기에 있음"},
        {"Mem_RemoveFav", "즐겨찾기에서 제거"},
        {"Mem_SendToPanel", "패널로 보내기"},
        {"Mem_SentToPanel", "패널로 보냄"},
        {"Mem_CopyAddr", "주소 복사"},
        {"Mem_AutoRefresh_On", "자동 새로고침 켜짐"},
        {"Mem_AutoRefresh_Off", "자동 새로고침 꺼짐"},

        // 퍼지 검색
        {"Fuz_Increased", "증가"},
        {"Fuz_Decreased", "감소"},
        {"Fuz_Unchanged", "변화 없음"},
        {"Fuz_Changed", "변화 있음"},
        {"Fuz_Inc_Val", "증가량..."},
        {"Fuz_Dec_Val", "감소량..."},
        {"Fuz_Hint_Increased", "값이 증가한 주소 필터"},
        {"Fuz_Hint_Decreased", "값이 감소한 주소 필터"},
        {"Fuz_Hint_Unchanged", "값이 변하지 않은 주소 필터"},
        {"Fuz_Hint_Changed", "값이 변한 주소 필터"},
        {"Fuz_Hint_Inc_Val", "지정 값만큼 증가한 주소 필터"},
        {"Fuz_Hint_Dec_Val", "지정 값만큼 감소한 주소 필터"},
        {"Fuz_Input_Delta", "변화량 입력"},
        {"Fuz_Select_Mode", "필터 모드 선택"},
        {"Fuz_Search_OK", "검색 성공, 값을 변경 후 계속 검색"},
        {"Fuz_Unchanged_TooMany", "결과가 너무 많습니다, 먼저 범위를 좁히세요"},
        {"Fuz_First_Hint", "검색을 클릭하여 시작"},

        // 필터 패널
        {"Filter_Btn", "필터"},
        {"Filter_Less", "미만"},
        {"Filter_Greater", "초과"},
        {"Filter_Between", "범위"},
        {"Filter_Apply", "적용"},
        {"Filter_Input_Min", "최소값"},
        {"Filter_Input_Max", "최대값"},
        {"Filter_Input_Val", "값"},

        // 근처 검색
        {"Nearby_Btn", "근처"},
        {"Nearby_Title", "근처 검색"},
        {"Nearby_Range", "범위 (바이트)"},
        {"Nearby_Value", "목표 값"},

        // 새로고침
        {"Refresh_Btn", "새로고침"},

        // 배치 작업
        {"Batch_Btn", "배치"},
        {"Batch_Modify", "배치 수정"},
        {"Batch_Modify_Hint", "처음 %lu개 결과 수정"},
        {"Batch_Copy", "주소 복사"},
        {"Batch_Copied", "%lu개 주소 복사됨"},
        {"Batch_Modified", "%lu개 주소 수정됨"},

        // 스크립트
        {"Script_Run", "스크립트 실행"},
        {"Script_ViewSource", "소스 보기"},
        {"Script_Running", "스크립트 실행 중..."},
        {"Script_Empty", "스크립트가 비어 있음"},
        {"Script_Done", "스크립트 완료"},

        // UI 텍스트 (이모지 대체)
        {"UI_Lock", "잠금"},
        {"UI_Unlock", "해제"},
        {"UI_Locked", "[L]"},
        {"UI_Unlocked", "L"},
        {"UI_Fav", "즐겨찾기"},
        {"UI_Unfav", "해제"},
        {"UI_Faved", "[F]"},
        {"UI_Unfaved", "F"},
        {"UI_View", "보기"},
        {"UI_Close", "X"},

        // 메모리 검색 탭
        {"Mem_Tab_Exact", "정확"},
        {"Mem_Tab_Fuzzy", "퍼지"},
        {"Mem_Tab_Group", "그룹"},

        {"Timeline_Title", "검색 타임라인"},
        {"Timeline_Empty", "검색 스냅샷 없음"},
        {"Timeline_Clear", "타임라인 지우기"},
        {"Timeline_Restored_Fmt", "%@ 복원됨 · %lu개"},
        {"Timeline_Restore_Failed", "복원 실패"},
        {"Timeline_Mode_Exact", "정확 검색"},
        {"Timeline_Mode_Fuzzy", "퍼지 검색"},
        {"Timeline_Mode_Group", "그룹 검색"},
        {"Timeline_Mode_Between", "범위 검색"},
        {"Undo_Last_Modify", "이전 수정 되돌리기"},
        {"Undo_Success", "수정이 되돌려짐"},
        {"Undo_Failed", "되돌리기 실패"},

        // 메모리 검색 추가
        {"Mem_GroupHint", "; 또는 ::로 값 구분"},
        {"Mem_BetweenHint", "범위 검색: 최소값~최대값 또는 최소값-최대값"},
        {"Err_Not_Numeric", "유효한 숫자를 입력하세요"},
        {"Err_Range_Invalid", "범위 형식이 잘못되었습니다"},
        {"Mem_Copied", "복사됨"},
        {"Mem_Actions", "작업"},
        {"Mem_Browse", "메모리 브라우즈"},
        {"Mem_HexView", "Hex 보기"},

        // 그룹 검색 도움말
        {"Group_Help_Title", "그룹 검색 가이드"},
        {"Group_Help_Msg", "메모리 순서로 여러 값을 검색합니다.\n\n1. 기본 (현재 유형 사용):\n   100; 200; 300\n   (값은 이 순서로 나타나야 함)\n\n2. 혼합 유형 (값+유형):\n   100 i32; 0.5 f32; 10 i8\n   (지원: i8, i16, i32, i64, f32, f64)\n\n3. 범위 지정 (끝에 :: 추가):\n   10; 20::100\n   (다음 값은 100바이트 이내)\n\n4. 구분자:\n   세미콜론 (;) 또는 공백 권장"},

        // 결과 패널
        {"Mem_Results", "검색 결과"},

        // 메모리 브라우저
        {"Mem_Browser_Title", "메모리 브라우저"},
        {"Mem_Hex_Title", "Hex 에디터"},
        {"Mem_Go", "이동"},
        {"Mem_NextPage", "다음"},
        {"Mem_PrevPage", "이전"},
        {"Mem_Copy", "복사"},
        {"Mem_ReadFailed", "메모리 읽기 실패"},

        // 새로고침
        {"Refresh_Btn", "새로고침"},
        {"Refresh_Done", "새로고침 완료"},

        // 도구 상자
        {"Toolbox_Title", "도구 상자"},
        {"Toolbox_FloatBtn", "도구 상자 플로팅 버튼"},
        {"Toolbox_FloatBtn_On", "도구 상자 버튼 활성화"},
        {"Toolbox_FloatBtn_Off", "도구 상자 버튼 비활성화"},

        // 검색 결과
        {"MemResults_FloatBtn", "결과 플로팅 버튼"},
        {"MemResults_FloatBtn_On", "결과 버튼 활성화"},
        {"MemResults_FloatBtn_Off", "결과 버튼 비활성화"},

        // 메모리 브라우저 플로팅
        {"MemBrowser_FloatBtn", "브라우저 플로팅 버튼"},
        {"MemBrowser_FloatBtn_On", "브라우저 버튼 활성화"},
        {"MemBrowser_FloatBtn_Off", "브라우저 버튼 비활성화"},

        // 플로팅 스위치 페이지
        {"Float_Desc", "플로팅 버튼 관리"},
        {"Float_MemSearch_Desc", "메모리 검색 빠른 접근"},
        {"Float_Toolbox_Desc", "도구 상자 빠른 접근"},
        {"Float_Results_Desc", "검색 결과 빠른 접근"},
        {"Float_Browser_Desc", "메모리 브라우저 빠른 접근"},
        {"Float_Position_Hint", "버튼은 오른쪽에 세로로 배열, 드래그하여 이동"},

        // 창 스위치 페이지
        {"Window_Desc", "플로팅 창 표시/숨기기"},
        {"Window_MemDebug_Title", "메모리 디버그"},
        {"Window_MemDebug_Desc", "메모리 검색 및 분석"},
        {"Window_MemResults_Title", "검색 결과"},
        {"Window_Toolbox_Desc", "다기능 도구 상자"},
        {"Window_Browser_Desc", "메모리 탐색 및 편집"},
        {"Window_Hint", "스위치를 클릭하여 창 표시. 창은 가장자리로 최소화 가능."},

        // 기타
        {"Script_Untitled", "제목 없는 스크립트"},

        // 가져오기
        {"Btn_Import", "가져오기"},
        {"Msg_Imported", "%ld개 항목 가져옴"},
        {"Msg_ImportFailed", "가져오기 실패 또는 잘못된 형식"},

        // Enable/Disable
        {"Msg_Enabled", "활성화됨"},
        {"Msg_Disabled", "비활성화됨"},

        // Touch Passthrough Mode
        {"Tool_TouchMode", "터치 통과 최적화"},
        {"Touch_Mode_Desc", "자동 클릭기 호환성 최적화"},
        {"Touch_Mode_On", "통과 모드 켜짐"},
        {"Touch_Mode_Off", "통과 모드 꺼짐"},

        // 파일 브라우저
        {"FileBrowser_Title", "파일 브라우저"},
        {"FileBrowser_Open", "파일 브라우저 열기"},
        {"FileBrowser_Back", "← 뒤로"},
        {"FileBrowser_Import", "파일 가져오기"},
        {"FileBrowser_Export", "내보내기"},
        {"FileBrowser_Delete", "삭제"},
        {"FileBrowser_DeleteConfirm", "삭제하시겠습니까?"},
        {"FileBrowser_Deleted", "삭제됨"},
        {"FileBrowser_DeleteFail", "삭제 실패"},
        {"FileBrowser_Imported", "%ld개 파일 가져옴"},
        {"FileBrowser_ImportFail", "가져오기 실패"},
        {"FileBrowser_ReadError", "디렉토리 읽기 실패"},
        {"FileBrowser_AtRoot", "루트 디렉토리입니다"},
        {"FileBrowser_Conflict", "파일이 이미 존재합니다"},
        {"FileBrowser_Overwrite", "덮어쓰기"},
        {"FileBrowser_Rename", "둘 다 유지"},
        {"FileBrowser_ImportFolder", "폴더 가져오기"},
        {"FileBrowser_ExportFolder", "폴더 내보내기 (zip)"},
        {"FileBrowser_OpenFolder", "열기"},
        {"FileBrowser_Zipping", "압축 중..."},
        {"FileBrowser_ZipFail", "압축 실패"},
        {"FileBrowser_Merge", "병합"},
        {"Window_FileBrowser_Desc", "앱 데이터 파일 탐색"},

        // 하드웨어 워치포인트
        {"Watch_Title", "워치포인트"},
        {"Watch_Btn", "감시"},
        {"Watch_Add", "워치포인트 추가"},
        {"Watch_Add_Msg", "감시할 메모리 주소 입력"},
        {"Watch_Active", "활성"},
        {"Watch_Empty", "비어있음"},
        {"Watch_Hits", "히트"},
        {"Watch_Slots", "슬롯"},
        {"Watch_ClearAll", "전체 삭제"},
        {"Watch_ClearAll_Msg", "모든 워치포인트와 기록을 삭제하시겠습니까?"},
        {"Watch_Cleared", "모든 워치포인트가 삭제되었습니다"},
        {"Watch_Added", "워치포인트 설정"},
        {"Watch_Removed", "워치포인트 삭제됨"},
        {"Watch_Trigger", "트리거"},
        {"Watch_StackTrace", "콜 스택"},
        {"Watch_HitDetail", "히트 상세"},
        {"Watch_CopyOffset", "오프셋 복사"},
        {"Watch_SendToRVA", "RVA로 전송"},
        {"Watch_SentToRVA", "RVA 도구함으로 전송됨"},
        {"Watch_JailbreakOnly", "탈옥 기기 전용"},
        {"Watch_Err_MaxSlots", "하드웨어 워치포인트 최대 4개"},
        {"Watch_Err_AddFailed", "워치포인트 설정 실패"},
        {"Watch_Err_InvalidAddr", "잘못된 주소"},
        {"Window_Watch_Desc", "하드웨어 브레이크포인트 모니터"},

        // 코드 인스펙터
        {"Inspector_Title", "코드 인스펙터"},
        {"Inspector_Patch", "패치"},
        {"Inspector_PatchHint", "HEX (예: C0035FD6)"},
        {"Inspector_Patched", "패치 완료"},
        {"Inspector_PatchFail", "패치 실패"},
        {"Inspector_NOP", "NOP"},
        {"Inspector_RET", "RET"},
        {"Inspector_ToRVA", "RVA로 전송"},
        {"Inspector_CopyHex", "Hex 복사"},
        {"Inspector_CopyAll", "전체 복사"},
        {"Inspector_HexOnly", "16진수 입력만 가능 (ASM은 armconverter.com 사용)"},
        {"Watch_RVAUpdated", "RVA 항목 업데이트됨"},

        // String Browser
        {"Browser_Str_Edit", "문자열 편집"},
        {"Browser_Str_OrigLen", "원래 길이:"},
        {"Browser_Str_Overflow", "문자열 오버플로"},
        {"Browser_Str_Overflow_Msg", "원래 %lu 바이트, 새 %lu 바이트. 인접 데이터가 손상될 수 있습니다."},
        {"Browser_Str_Force_Write", "강제 쓰기"},

        // Icon Picker
        {"Msg_IconChanged", "아이콘이 변경되었습니다"},
    };
}
