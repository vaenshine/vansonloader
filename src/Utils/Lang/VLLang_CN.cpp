/**
 * VansonLoader - 简体中文语言包
 */

#include <map>
#include <string>

std::map<std::string, std::string> getLangCN() {
    return {
        // Tab 标签
        {"Tab_Ptr", "指针"},
        {"Tab_RVA", "RVA"},
        {"Tab_Sig", "特征码"},
        {"Tab_Search", "内存"},
        {"Tab_Tool", "工具"},
        {"Tab_Assist", "辅助"},
        {"Tab_Window", "窗口"},
        {"Tab_About", "关于"},
        {"Tab_Mem", "内存"},
        {"Tab_Fav", "收藏"},
        {"Tab_Script", "脚本"},
        {"Tab_Watch", "监控"},
        {"Tab_MemBrowser", "浏览"},
        {"Tab_Lock", "锁定"},
        {"Btn_Back", "返回"},

        // 按钮
        {"Btn_Modify", "修改"},
        {"Btn_Refresh", "刷新数值"},
        {"Btn_View", "查看"},
        {"Btn_Search", "搜索"},
        {"Btn_Scan", "匹配"},
        {"Btn_Cancel", "取消"},
        {"Btn_Close", "关闭"},
        {"Btn_OK", "确定"},
        {"Btn_Edit", "编辑"},
        {"Btn_Delete", "删除"},
        {"Btn_Done", "完成"},

        // 面板缩放
        {"Size_Small", "小"},
        {"Size_Medium", "中"},
        {"Size_Large", "大"},

        // 工具页
        {"Tool_Clicker", "连点器"},
        {"Tool_Dump", "数据导出"},
        {"Tool_Config", "配置管理"},

        // 空状态
        {"Empty_Ptr", "暂无指针配置"},
        {"Empty_RVA", "暂无RVA配置"},
        {"Empty_Sig", "暂无特征码配置"},
        {"Empty_Hint", "工具 -> 导入配置"},
        {"Empty_Mem", "暂无搜索结果"},
        {"Empty_Mem_Hint", "使用悬浮按钮搜索内存"},
        {"Empty_Fav", "暂无收藏"},
        {"Empty_Fav_Hint", "从内存结果中添加收藏"},
        {"Empty_Script", "暂无脚本"},
        {"Empty_Script_Hint", "导入 .vmsc 脚本文件"},

        // 配置管理
        {"Config_Import", "导入配置"},
        {"Config_Delete", "删除配置"},
        {"Config_DeleteConfirm", "确定要删除当前配置并清空菜单吗？"},
        {"Config_Deleted", "配置已删除"},
        {"Config_ImportSuccess", "导入成功"},
        {"Config_ImportError", "格式错误或解密失败"},

        // 连点器
        {"Click_AddPt", "添加点位"},
        {"Click_Undo", "撤销"},
        {"Click_Start", "启动"},
        {"Click_Stop", "停止"},
        {"Click_NoPoints", "请先添加点击点位"},
        {"Click_Freq", "频率:"},
        {"Click_Points", "点位:"},

        // Dump
        {"Dump_Btn", "Dump Unity Metadata + Binary"},

        // RVA 警告
        {"RVA_Warning", "仅限越狱设备"},

        // 关于页
        {"About_Title", "VansonLoader"},
        {"About_Telegram", "Telegram @VansonMod"},
        {"About_Lang", "Languages"},
        {"About_Disclaimer", "免责声明"},
        {"Disclaimer_Agreed", "已同意免责声明"},
        {"Disclaimer_Tap", "点击查看"},
        {"Disclaimer_Agree", "我同意"},
        {"Disclaimer_Reject", "拒绝"},
        {"Disclaimer_Rejected", "已拒绝，正在退出..."},
        {"Disclaimer_Exit", "退出"},
        {"Disclaimer_Text", "・本项目以 GPL-3.0 协议开源，仅限安全研究、逆向工程学习及合规测试场景使用。\n\n・请在合法授权环境中使用，并遵守目标应用与系统的适用规则。\n\n・使用本工具产生的操作风险、损失及法律责任由使用者自行承担。\n\n・点击「我同意」即代表您已完整阅读并自愿接受以上条款。"},
        {"Disclaimer_Content", "・本项目以 GPL-3.0 协议开源，仅限安全研究、逆向工程学习及合规测试场景使用。\n\n・请在合法授权环境中使用，并遵守目标应用与系统的适用规则。\n\n・使用本工具产生的操作风险、损失及法律责任由使用者自行承担。\n\n・点击「我同意」即代表您已完整阅读并自愿接受以上条款。"},

        // Toast 消息
        {"Msg_ImportSuccess", "导入成功"},
        {"Msg_ImportError", "格式错误"},
        {"Msg_Locked", "已锁定"},
        {"Msg_Unlocked", "已解锁"},
        {"Msg_Patched", "已注入"},
        {"Msg_Restored", "已还原"},
        {"Msg_WriteFail", "写入失败"},
        {"Msg_ModuleNotFound", "模块未找到"},
        {"Msg_Scanning", "扫描中..."},
        {"Msg_ScanComplete", "扫描完成"},
        {"Msg_NoResult", "未找到结果"},
        {"Msg_Saved", "已保存"},
        {"Msg_LangChanged", "语言已更改"},
        {"Msg_Matched", "匹配成功"},
        {"Msg_MultiMatch", "个匹配"},
        {"Msg_UniqueMatch", "唯一匹配"},
        {"Msg_ClickToScan", "点击匹配按钮搜索"},
        {"Msg_WriteFailed", "写入失败"},
        {"Msg_MoreMatches", "+%lu 更多"},

        // Cell 信息
        {"Cell_RVA", "RVA: 0x%llX"},
        {"Cell_Unnamed", "未命名"},
        {"Cell_Result", "结果"},

        // 特征码
        {"Sig_Addr", "地址"},

        // 弹窗
        {"Alert_Cancel", "取消"},
        {"Alert_Confirm", "确认"},
        {"Alert_Current", "当前值: %@"},

        // 编辑器
        {"Edit_Title", "编辑项目"},
        {"Edit_Save", "保存"},
        {"Edit_Section_Basic", "基本信息"},
        {"Edit_Section_UI", "UI 模式"},
        {"Edit_Section_Slider", "滑块配置"},
        {"Edit_Section_Switch", "开关配置"},
        {"Edit_Note", "备注"},
        {"Edit_Value", "数值"},
        {"Edit_UIMode", "UI 模式"},
        {"Edit_DataType", "数据类型"},
        {"Edit_Author", "作者"},
        {"Edit_Min", "最小值"},
        {"Edit_Max", "最大值"},
        {"Edit_OnValue", "开启值"},
        {"Edit_OffValue", "关闭值"},
        {"Edit_Section_RVA", "RVA 补丁"},
        {"Edit_Module", "框架"},
        {"Edit_Offset", "偏移量"},
        {"Edit_PatchHex", "补丁 HEX"},
        {"Edit_OrigHex", "原始 HEX"},

        // UI 模式
        {"Mode_Card", "卡片"},
        {"Mode_Slider", "滑块"},
        {"Mode_Switch", "开关"},
        {"About_Version", "版本 %@"},
        {"About_License", "v3.1: 搜索时间线、结果恢复、写入撤回\nOpen Source: GPL-3.0"},

        // 内存调试 (原内存搜索)
        {"Mem_Title", "内存搜索"},
        {"Mem_Debug_Title", "内存调试"},
        {"Mem_OpenSearch", "打开内存调试"},
        {"Mem_Status", "搜索状态"},
        {"Mem_NoResults", "暂无结果"},
        {"Mem_Exact", "精确"},
        {"Mem_Fuzzy", "模糊"},
        {"Mem_Range", "范围"},
        {"Mem_InputValue", "输入搜索值"},
        {"Mem_Search", "首次搜索"},
        {"Mem_Next", "再次搜索"},
        {"Mem_Reset", "重置"},
        {"Mem_Ready", "就绪"},
        {"Mem_Empty", "暂无结果"},
        {"Mem_Searching", "搜索中..."},
        {"Mem_Filtering", "筛选中..."},
        {"Mem_Found", "找到"},
        {"Mem_InputRequired", "请输入搜索值"},
        {"Mem_LoadMore", "加载更多"},
        {"Mem_NoMore", "没有更多了"},
        {"Mem_NewValue", "新数值"},
        {"Mem_Write", "写入"},
        {"Mem_WriteOK", "写入成功"},
        {"Mem_WriteFail", "写入失败"},
        {"Mem_Browser", "浏览"},
        {"Mem_Hex", "Hex"},
        {"Mem_Settings", "设置"},
        {"Mem_FloatTol", "浮点容差"},
        {"Mem_GroupRange", "联合搜索范围"},
        {"Mem_TakingSnapshot", "正在打快照..."},
        {"Mem_Snapshot_Ready", "快照就绪，地址数"},
        {"Mem_Error", "操作失败"},
        {"Mem_FloatDebug", "悬浮内存调试"},
        {"Mem_FloatDebug_On", "已开启"},
        {"Mem_FloatDebug_Off", "已关闭"},
        {"Mem_AddFav", "添加收藏"},
        {"Mem_AddedFav", "已添加到收藏"},
        {"Mem_AlreadyFav", "已在收藏中"},
        {"Mem_RemoveFav", "取消收藏"},
        {"Mem_SendToPanel", "发送到面板"},
        {"Mem_SentToPanel", "已发送到面板"},
        {"Mem_CopyAddr", "复制地址"},
        {"Mem_AutoRefresh_On", "自动刷新已开启"},
        {"Mem_AutoRefresh_Off", "自动刷新已关闭"},

        // 模糊搜索
        {"Fuz_Increased", "变大"},
        {"Fuz_Decreased", "变小"},
        {"Fuz_Unchanged", "无变化"},
        {"Fuz_Changed", "变动"},
        {"Fuz_Inc_Val", "增加了..."},
        {"Fuz_Dec_Val", "减少了..."},
        {"Fuz_Hint_Increased", "筛选值变大的地址"},
        {"Fuz_Hint_Decreased", "筛选值变小的地址"},
        {"Fuz_Hint_Unchanged", "筛选值未变化的地址"},
        {"Fuz_Hint_Changed", "筛选值有变化的地址"},
        {"Fuz_Hint_Inc_Val", "筛选增加了指定值的地址"},
        {"Fuz_Hint_Dec_Val", "筛选减少了指定值的地址"},
        {"Fuz_Input_Delta", "输入变化量"},
        {"Fuz_Select_Mode", "请选择筛选模式"},
        {"Fuz_Search_OK", "搜索成功，改变数值后继续搜索"},
        {"Fuz_Unchanged_TooMany", "结果过多，请先缩小范围"},
        {"Fuz_First_Hint", "点击搜索开始"},

        // 筛选面板
        {"Filter_Btn", "筛选"},
        {"Filter_Less", "小于"},
        {"Filter_Greater", "大于"},
        {"Filter_Between", "范围"},
        {"Filter_Apply", "应用"},
        {"Filter_Input_Min", "最小值"},
        {"Filter_Input_Max", "最大值"},
        {"Filter_Input_Val", "输入值"},

        // 临近搜索
        {"Nearby_Btn", "临近"},
        {"Nearby_Title", "临近搜索"},
        {"Nearby_Range", "搜索范围 (字节)"},
        {"Nearby_Value", "目标值"},

        // 刷新
        {"Refresh_Btn", "刷新"},
        {"Refresh_Done", "已刷新"},

        // 批量操作
        {"Batch_Btn", "批量"},
        {"Batch_Modify", "批量修改"},
        {"Batch_Modify_Hint", "修改前 %lu 个结果"},
        {"Batch_Copy", "复制地址"},
        {"Batch_Copied", "已复制 %lu 个地址"},
        {"Batch_Modified", "已修改 %lu 个地址"},
        {"Batch_Select", "选择"},
        {"Batch_Action", "批量"},
        {"Batch_NoSelection", "未选择地址"},
        {"Batch_Selected_Count", "已选择 %lu 个地址"},
        {"Batch_Fixed", "固定值修改"},
        {"Batch_Increment", "递增修改"},
        {"Batch_Start_Value", "起始值"},
        {"Batch_Select_All", "全选当前页"},
        {"Batch_Exit_Select", "退出选择"},

        // 脚本
        {"Script_Run", "运行脚本"},
        {"Script_ViewSource", "查看源码"},
        {"Script_Running", "脚本运行中..."},
        {"Script_Empty", "脚本内容为空"},
        {"Script_Done", "脚本执行完成"},

        // UI 文本 (替换 emoji)
        {"UI_Lock", "锁定"},
        {"UI_Unlock", "解锁"},
        {"UI_Locked", "[锁定]"},
        {"UI_Unlocked", "锁定"},
        {"UI_Fav", "收藏"},
        {"UI_Unfav", "取消"},
        {"UI_Faved", "[收藏]"},
        {"UI_Unfaved", "收藏"},
        {"UI_View", "查看"},
        {"UI_Close", "X"},

        // 内存搜索 Tab
        {"Mem_Tab_Exact", "精确"},
        {"Mem_Tab_Fuzzy", "模糊"},
        {"Mem_Tab_Group", "联合"},

        {"Timeline_Title", "搜索时间线"},
        {"Timeline_Empty", "暂无搜索快照"},
        {"Timeline_Clear", "清空时间线"},
        {"Timeline_Restored_Fmt", "已恢复 %@ · %lu 条"},
        {"Timeline_Restore_Failed", "恢复失败"},
        {"Timeline_Mode_Exact", "精确搜索"},
        {"Timeline_Mode_Fuzzy", "模糊搜索"},
        {"Timeline_Mode_Group", "联合搜索"},
        {"Timeline_Mode_Between", "范围搜索"},
        {"Undo_Last_Modify", "撤回上次修改"},
        {"Undo_Success", "已撤回修改"},
        {"Undo_Failed", "撤回失败"},

        // 内存搜索附加
        {"Mem_GroupHint", "使用 ; 或 :: 分隔多个值"},
        {"Mem_BetweenHint", "范围搜索: 输入 最小值~最大值 或 最小值-最大值"},
        {"Err_Not_Numeric", "请输入有效数值"},
        {"Err_Range_Invalid", "范围格式无效"},
        {"Mem_Copied", "已复制"},
        {"Mem_Actions", "操作"},
        {"Mem_Browse", "浏览内存"},
        {"Mem_HexView", "Hex 查看"},

        // 联合搜索帮助
        {"Group_Help_Title", "联合搜索使用指南"},
        {"Group_Help_Msg", "按内存顺序搜索多个数值。\n\n1. 基础用法 (使用当前选择类型):\n   100; 200; 300\n   (数值必须按此顺序出现)\n\n2. 混合类型 (数值+类型):\n   100 i32; 0.5 f32; 10 i8\n   (支持: i8, i16, i32, i64, f32, f64)\n\n3. 指定范围 (末尾加 ::):\n   10; 20::100\n   (下一个数值在 100 字节内)\n\n4. 分隔符:\n   推荐使用分号 (;) 或空格"},

        // 结果面板
        {"Mem_Results", "搜索结果"},

        // 工具箱
        {"Toolbox_Title", "工具箱"},
        {"Toolbox_FloatBtn", "工具箱悬浮按钮"},
        {"Toolbox_FloatBtn_On", "工具箱按钮已启用"},
        {"Toolbox_FloatBtn_Off", "工具箱按钮已禁用"},

        // 搜索结果
        {"MemResults_FloatBtn", "结果悬浮按钮"},
        {"MemResults_FloatBtn_On", "结果按钮已启用"},
        {"MemResults_FloatBtn_Off", "结果按钮已禁用"},

        // 内存浏览器悬浮
        {"MemBrowser_FloatBtn", "浏览器悬浮按钮"},
        {"MemBrowser_FloatBtn_On", "浏览器按钮已启用"},
        {"MemBrowser_FloatBtn_Off", "浏览器按钮已禁用"},

        // 窗口开关页面
        {"Window_Desc", "显示/隐藏悬浮窗口"},
        {"Window_MemDebug_Title", "内存调试"},
        {"Window_MemDebug_Desc", "内存搜索与分析"},
        {"Window_MemResults_Title", "搜索结果"},
        {"Window_Toolbox_Desc", "多功能工具箱"},
        {"Window_Browser_Desc", "浏览和编辑内存"},
        {"Window_Hint", "点击开关显示窗口，窗口可收起到屏幕边缘"},

        // 内存浏览器
        {"Mem_Browser_Title", "内存浏览器"},
        {"Mem_Hex_Title", "Hex 编辑器"},
        {"Mem_Go", "跳转"},
        {"Mem_NextPage", "下一页"},
        {"Mem_PrevPage", "上一页"},
        {"Mem_Copy", "复制"},
        {"Mem_ReadFailed", "读取内存失败"},

        // 脚本
        {"Script_Untitled", "未命名脚本"},

        // 导入
        {"Btn_Import", "导入"},
        {"Msg_Imported", "已导入 %ld 项"},
        {"Msg_ImportFailed", "导入失败或格式无效"},

        // Enable/Disable
        {"Msg_Enabled", "已启用"},
        {"Msg_Disabled", "已禁用"},

        // Touch Passthrough Mode
        {"Tool_TouchMode", "触摸穿透优化"},
        {"Touch_Mode_Desc", "优化连点器兼容性"},
        {"Touch_Mode_On", "穿透模式已开启"},
        {"Touch_Mode_Off", "穿透模式已关闭"},

        // 文件浏览器
        {"FileBrowser_Title", "文件浏览器"},
        {"FileBrowser_Open", "打开文件浏览器"},
        {"FileBrowser_Back", "← 返回"},
        {"FileBrowser_Import", "导入文件"},
        {"FileBrowser_Export", "导出"},
        {"FileBrowser_Delete", "删除"},
        {"FileBrowser_DeleteConfirm", "确认删除？"},
        {"FileBrowser_Deleted", "已删除"},
        {"FileBrowser_DeleteFail", "删除失败"},
        {"FileBrowser_Imported", "已导入 %ld 个文件"},
        {"FileBrowser_ImportFail", "导入失败"},
        {"FileBrowser_ReadError", "读取目录失败"},
        {"FileBrowser_AtRoot", "已在根目录"},
        {"FileBrowser_Conflict", "文件已存在"},
        {"FileBrowser_Overwrite", "覆盖"},
        {"FileBrowser_Rename", "保留两者"},
        {"FileBrowser_ImportFolder", "导入文件夹"},
        {"FileBrowser_ExportFolder", "导出文件夹 (zip)"},
        {"FileBrowser_OpenFolder", "打开"},
        {"FileBrowser_Zipping", "压缩中..."},
        {"FileBrowser_ZipFail", "压缩失败"},
        {"FileBrowser_Merge", "合并"},
        {"Window_FileBrowser_Desc", "浏览应用数据文件"},

        // 硬件断点监控
        {"Watch_Title", "断点监控"},
        {"Watch_Btn", "监控"},
        {"Watch_Add", "添加断点"},
        {"Watch_Add_Msg", "输入要监控的内存地址"},
        {"Watch_Active", "活跃"},
        {"Watch_Empty", "空闲"},
        {"Watch_Hits", "触发"},
        {"Watch_Slots", "槽位"},
        {"Watch_ClearAll", "全部清除"},
        {"Watch_ClearAll_Msg", "移除所有断点和触发记录?"},
        {"Watch_Cleared", "已清除所有断点"},
        {"Watch_Added", "断点已设置于"},
        {"Watch_Removed", "断点已移除"},
        {"Watch_Trigger", "触发点"},
        {"Watch_StackTrace", "调用堆栈"},
        {"Watch_HitDetail", "触发详情"},
        {"Watch_CopyOffset", "复制偏移量"},
        {"Watch_SendToRVA", "发送到 RVA"},
        {"Watch_SentToRVA", "已发送到 RVA 工具箱"},
        {"Watch_JailbreakOnly", "仅限越狱设备"},
        {"Watch_Err_MaxSlots", "最多 4 个硬件断点"},
        {"Watch_Err_AddFailed", "断点设置失败"},
        {"Watch_Err_InvalidAddr", "无效地址"},
        {"Window_Watch_Desc", "硬件断点监控"},

        // 代码检视器
        {"Inspector_Title", "代码检视器"},
        {"Inspector_Patch", "修补"},
        {"Inspector_PatchHint", "HEX (如 C0035FD6)"},
        {"Inspector_Patched", "已修补"},
        {"Inspector_PatchFail", "修补失败"},
        {"Inspector_NOP", "NOP"},
        {"Inspector_RET", "RET"},
        {"Inspector_ToRVA", "发送到 RVA"},
        {"Inspector_CopyHex", "复制 Hex"},
        {"Inspector_CopyAll", "复制全部"},
        {"Inspector_HexOnly", "仅支持十六进制输入 (汇编请用 armconverter.com)"},
        {"Watch_RVAUpdated", "已更新 RVA 项"},

        // String Browser
        {"Browser_Str_Edit", "编辑字符串"},
        {"Browser_Str_OrigLen", "原始长度:"},
        {"Browser_Str_Overflow", "字符串溢出"},
        {"Browser_Str_Overflow_Msg", "原始 %lu 字节，新 %lu 字节，可能破坏相邻数据。"},
        {"Browser_Str_Force_Write", "强制写入"},

        // Icon Picker
        {"Msg_IconChanged", "图标已更换"},
    };
}
