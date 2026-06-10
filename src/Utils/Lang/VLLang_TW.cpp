/**
 * VansonLoader - 繁體中文語言包
 */

#include <map>
#include <string>

std::map<std::string, std::string> getLangTW() {
    return {
        // Tab 標籤
        {"Tab_Ptr", "指標"},
        {"Tab_RVA", "RVA"},
        {"Tab_Sig", "特徵碼"},
        {"Tab_Search", "記憶體"},
        {"Tab_Tool", "工具"},
        {"Tab_Assist", "輔助"},
        {"Tab_Window", "視窗"},
        {"Tab_About", "關於"},
        {"Tab_Mem", "記憶體"},
        {"Tab_Fav", "收藏"},
        {"Tab_Script", "腳本"},
        {"Tab_Watch", "監控"},
        {"Tab_MemBrowser", "瀏覽"},
        {"Tab_Lock", "鎖定"},
        {"Btn_Back", "返回"},

        // 按鈕
        {"Btn_Modify", "修改"},
        {"Btn_Refresh", "刷新數值"},
        {"Btn_View", "查看"},
        {"Btn_Search", "搜尋"},
        {"Btn_Scan", "匹配"},
        {"Btn_Cancel", "取消"},
        {"Btn_Close", "關閉"},
        {"Btn_OK", "確定"},
        {"Btn_Edit", "編輯"},
        {"Btn_Delete", "刪除"},
        {"Btn_Done", "完成"},

        // 面板縮放
        {"Size_Small", "小"},
        {"Size_Medium", "中"},
        {"Size_Large", "大"},

        // 工具頁
        {"Tool_Clicker", "連點器"},
        {"Tool_Dump", "資料匯出"},
        {"Tool_Config", "配置管理"},

        // 空狀態
        {"Empty_Ptr", "暫無指標配置"},
        {"Empty_RVA", "暫無RVA配置"},
        {"Empty_Sig", "暫無特徵碼配置"},
        {"Empty_Hint", "工具 -> 匯入配置"},
        {"Empty_Mem", "暫無搜尋結果"},
        {"Empty_Mem_Hint", "使用懸浮按鈕搜尋記憶體"},
        {"Empty_Fav", "暫無收藏"},
        {"Empty_Fav_Hint", "從記憶體結果中添加收藏"},
        {"Empty_Script", "暫無腳本"},
        {"Empty_Script_Hint", "匯入 .vmsc 腳本檔案"},

        // 配置管理
        {"Config_Import", "匯入配置"},
        {"Config_Delete", "刪除配置"},
        {"Config_DeleteConfirm", "確定要刪除當前配置並清空選單嗎？"},
        {"Config_Deleted", "配置已刪除"},
        {"Config_ImportSuccess", "匯入成功"},
        {"Config_ImportError", "格式錯誤或解密失敗"},

        // 連點器
        {"Click_AddPt", "添加點位"},
        {"Click_Undo", "撤銷"},
        {"Click_Start", "啟動"},
        {"Click_Stop", "停止"},
        {"Click_NoPoints", "請先添加點擊點位"},
        {"Click_Freq", "頻率:"},
        {"Click_Points", "點位:"},

        // Dump
        {"Dump_Btn", "Dump Unity Metadata + Binary"},

        // RVA 警告
        {"RVA_Warning", "僅限越獄設備"},

        // 關於頁
        {"About_Title", "VansonLoader"},
        {"About_Telegram", "Telegram @VansonMod"},
        {"About_Lang", "Languages"},
        {"About_Disclaimer", "免責聲明"},
        {"Disclaimer_Agreed", "已同意免責聲明"},
        {"Disclaimer_Tap", "點擊查看"},
        {"Disclaimer_Agree", "我同意"},
        {"Disclaimer_Reject", "拒絕"},
        {"Disclaimer_Rejected", "已拒絕，正在退出..."},
        {"Disclaimer_Exit", "退出"},
        {"Disclaimer_Text", "・本專案以 GPL-3.0 協議開源，僅限安全研究、逆向工程學習及合規測試場景使用。\n\n・請在合法授權環境中使用，並遵守目標應用與系統的適用規則。\n\n・使用本工具產生的操作風險、損失及法律責任由使用者自行承擔。\n\n・點擊「我同意」即代表您已完整閱讀並自願接受以上條款。"},
        {"Disclaimer_Content", "・本專案以 GPL-3.0 協議開源，僅限安全研究、逆向工程學習及合規測試場景使用。\n\n・請在合法授權環境中使用，並遵守目標應用與系統的適用規則。\n\n・使用本工具產生的操作風險、損失及法律責任由使用者自行承擔。\n\n・點擊「我同意」即代表您已完整閱讀並自願接受以上條款。"},

        // Toast 訊息
        {"Msg_ImportSuccess", "匯入成功"},
        {"Msg_ImportError", "格式錯誤"},
        {"Msg_Locked", "已鎖定"},
        {"Msg_Unlocked", "已解鎖"},
        {"Msg_Patched", "已注入"},
        {"Msg_Restored", "已還原"},
        {"Msg_WriteFail", "寫入失敗"},
        {"Msg_ModuleNotFound", "模組未找到"},
        {"Msg_Scanning", "掃描中..."},
        {"Msg_ScanComplete", "掃描完成"},
        {"Msg_NoResult", "未找到結果"},
        {"Msg_Saved", "已儲存"},
        {"Msg_LangChanged", "語言已更改"},
        {"Msg_Matched", "匹配成功"},
        {"Msg_MultiMatch", "個匹配"},
        {"Msg_UniqueMatch", "唯一匹配"},
        {"Msg_ClickToScan", "點擊匹配按鈕搜尋"},
        {"Msg_WriteFailed", "寫入失敗"},
        {"Msg_MoreMatches", "+%lu 更多"},

        // Cell 資訊
        {"Cell_RVA", "RVA: 0x%llX"},
        {"Cell_Unnamed", "未命名"},
        {"Cell_Result", "結果"},

        // 特徵碼
        {"Sig_Addr", "地址"},

        // 彈窗
        {"Alert_Cancel", "取消"},
        {"Alert_Confirm", "確認"},
        {"Alert_Current", "當前值: %@"},

        // 編輯器
        {"Edit_Title", "編輯項目"},
        {"Edit_Save", "儲存"},
        {"Edit_Section_Basic", "基本資訊"},
        {"Edit_Section_UI", "UI 模式"},
        {"Edit_Section_Slider", "滑塊配置"},
        {"Edit_Section_Switch", "開關配置"},
        {"Edit_Note", "備註"},
        {"Edit_Value", "數值"},
        {"Edit_UIMode", "UI 模式"},
        {"Edit_DataType", "資料類型"},
        {"Edit_Author", "作者"},
        {"Edit_Min", "最小值"},
        {"Edit_Max", "最大值"},
        {"Edit_OnValue", "開啟值"},
        {"Edit_OffValue", "關閉值"},
        {"Edit_Section_RVA", "RVA 補丁"},
        {"Edit_Module", "框架"},
        {"Edit_Offset", "偏移量"},
        {"Edit_PatchHex", "補丁 HEX"},
        {"Edit_OrigHex", "原始 HEX"},

        // UI 模式
        {"Mode_Card", "卡片"},
        {"Mode_Slider", "滑塊"},
        {"Mode_Switch", "開關"},
        {"About_Version", "版本 %@"},
        {"About_License", "v3.1: 搜尋時間線、結果恢復、寫入撤回\nOpen Source: GPL-3.0"},

        // 記憶體搜尋
        {"Mem_Title", "記憶體搜尋"},
        {"Mem_Debug_Title", "記憶體調試"},
        {"Mem_OpenSearch", "開啟記憶體調試"},
        {"Mem_Status", "搜尋狀態"},
        {"Mem_NoResults", "暫無結果"},
        {"Mem_Exact", "精確"},
        {"Mem_Fuzzy", "模糊"},
        {"Mem_Range", "範圍"},
        {"Mem_InputValue", "輸入搜尋值"},
        {"Mem_Search", "首次搜尋"},
        {"Mem_Next", "再次搜尋"},
        {"Mem_Reset", "重置"},
        {"Mem_Ready", "就緒"},
        {"Mem_Empty", "暫無結果"},
        {"Mem_Searching", "搜尋中..."},
        {"Mem_Filtering", "篩選中..."},
        {"Mem_Found", "找到"},
        {"Mem_InputRequired", "請輸入搜尋值"},
        {"Mem_LoadMore", "載入更多"},
        {"Mem_NoMore", "沒有更多了"},
        {"Mem_NewValue", "新數值"},
        {"Mem_Write", "寫入"},
        {"Mem_WriteOK", "寫入成功"},
        {"Mem_WriteFail", "寫入失敗"},
        {"Mem_Browser", "瀏覽"},
        {"Mem_Hex", "Hex"},
        {"Mem_Settings", "設定"},
        {"Mem_FloatTol", "浮點容差"},
        {"Mem_GroupRange", "聯合搜尋範圍"},
        {"Mem_TakingSnapshot", "正在打快照..."},
        {"Mem_Snapshot_Ready", "快照就緒，地址數"},
        {"Mem_Error", "操作失敗"},
        {"Mem_FloatDebug", "懸浮記憶體調試"},
        {"Mem_FloatDebug_On", "已開啟"},
        {"Mem_FloatDebug_Off", "已關閉"},
        {"Mem_AddFav", "添加收藏"},
        {"Mem_AddedFav", "已添加到收藏"},
        {"Mem_AlreadyFav", "已在收藏中"},
        {"Mem_RemoveFav", "取消收藏"},
        {"Mem_SendToPanel", "發送到面板"},
        {"Mem_SentToPanel", "已發送到面板"},
        {"Mem_CopyAddr", "複製地址"},
        {"Mem_AutoRefresh_On", "自動刷新已開啟"},
        {"Mem_AutoRefresh_Off", "自動刷新已關閉"},

        // 模糊搜尋
        {"Fuz_Increased", "變大"},
        {"Fuz_Decreased", "變小"},
        {"Fuz_Unchanged", "無變化"},
        {"Fuz_Changed", "變動"},
        {"Fuz_Inc_Val", "增加了..."},
        {"Fuz_Dec_Val", "減少了..."},
        {"Fuz_Hint_Increased", "篩選值變大的地址"},
        {"Fuz_Hint_Decreased", "篩選值變小的地址"},
        {"Fuz_Hint_Unchanged", "篩選值未變化的地址"},
        {"Fuz_Hint_Changed", "篩選值有變化的地址"},
        {"Fuz_Hint_Inc_Val", "篩選增加了指定值的地址"},
        {"Fuz_Hint_Dec_Val", "篩選減少了指定值的地址"},
        {"Fuz_Input_Delta", "輸入變化量"},
        {"Fuz_Select_Mode", "請選擇篩選模式"},
        {"Fuz_Search_OK", "搜尋成功，改變數值後繼續搜尋"},
        {"Fuz_Unchanged_TooMany", "結果過多，請先縮小範圍"},
        {"Fuz_First_Hint", "點擊搜尋開始"},

        // 篩選面板
        {"Filter_Btn", "篩選"},
        {"Filter_Less", "小於"},
        {"Filter_Greater", "大於"},
        {"Filter_Between", "範圍"},
        {"Filter_Apply", "應用"},
        {"Filter_Input_Min", "最小值"},
        {"Filter_Input_Max", "最大值"},
        {"Filter_Input_Val", "輸入值"},

        // 附近搜尋
        {"Nearby_Btn", "附近"},
        {"Nearby_Title", "附近搜尋"},
        {"Nearby_Range", "搜尋範圍 (位元組)"},
        {"Nearby_Value", "目標值"},

        // 刷新
        {"Refresh_Btn", "刷新"},

        // 批量操作
        {"Batch_Btn", "批量"},
        {"Batch_Modify", "批量修改"},
        {"Batch_Modify_Hint", "修改前 %lu 個結果"},
        {"Batch_Copy", "複製地址"},
        {"Batch_Copied", "已複製 %lu 個地址"},
        {"Batch_Modified", "已修改 %lu 個地址"},

        // 腳本
        {"Script_Run", "執行腳本"},
        {"Script_ViewSource", "查看原始碼"},
        {"Script_Running", "腳本執行中..."},
        {"Script_Empty", "腳本內容為空"},
        {"Script_Done", "腳本執行完成"},

        // UI 文字 (替換 emoji)
        {"UI_Lock", "鎖定"},
        {"UI_Unlock", "解鎖"},
        {"UI_Locked", "[鎖]"},
        {"UI_Unlocked", "鎖"},
        {"UI_Fav", "收藏"},
        {"UI_Unfav", "取消"},
        {"UI_Faved", "[收]"},
        {"UI_Unfaved", "收"},
        {"UI_View", "查看"},
        {"UI_Close", "X"},

        // 記憶體搜尋 Tab
        {"Mem_Tab_Exact", "精確"},
        {"Mem_Tab_Fuzzy", "模糊"},
        {"Mem_Tab_Group", "聯合"},

        {"Timeline_Title", "搜尋時間線"},
        {"Timeline_Empty", "暫無搜尋快照"},
        {"Timeline_Clear", "清空時間線"},
        {"Timeline_Restored_Fmt", "已恢復 %@ · %lu 筆"},
        {"Timeline_Restore_Failed", "恢復失敗"},
        {"Timeline_Mode_Exact", "精確搜尋"},
        {"Timeline_Mode_Fuzzy", "模糊搜尋"},
        {"Timeline_Mode_Group", "聯合搜尋"},
        {"Timeline_Mode_Between", "範圍搜尋"},
        {"Undo_Last_Modify", "撤回上次修改"},
        {"Undo_Success", "已撤回修改"},
        {"Undo_Failed", "撤回失敗"},

        // 記憶體搜尋附加
        {"Mem_GroupHint", "使用 ; 或 :: 分隔多個值"},
        {"Mem_BetweenHint", "範圍搜尋: 輸入 最小值~最大值 或 最小值-最大值"},
        {"Err_Not_Numeric", "請輸入有效數值"},
        {"Err_Range_Invalid", "範圍格式無效"},
        {"Mem_Copied", "已複製"},
        {"Mem_Actions", "操作"},
        {"Mem_Browse", "瀏覽記憶體"},
        {"Mem_HexView", "Hex 查看"},

        // 聯合搜索幫助
        {"Group_Help_Title", "聯合搜索使用指南"},
        {"Group_Help_Msg", "按記憶體順序搜索多個數值。\n\n1. 基礎用法 (使用當前選擇類型):\n   100; 200; 300\n   (數值必須按此順序出現)\n\n2. 混合類型 (數值+類型):\n   100 i32; 0.5 f32; 10 i8\n   (支持: i8, i16, i32, i64, f32, f64)\n\n3. 指定範圍 (末尾加 ::):\n   10; 20::100\n   (下一個數值在 100 字節內)\n\n4. 分隔符:\n   推薦使用分號 (;) 或空格"},

        // 結果面板
        {"Mem_Results", "搜尋結果"},

        // 記憶體瀏覽器
        {"Mem_Browser_Title", "記憶體瀏覽器"},
        {"Mem_Hex_Title", "Hex 編輯器"},
        {"Mem_Go", "跳轉"},
        {"Mem_NextPage", "下一頁"},
        {"Mem_PrevPage", "上一頁"},
        {"Mem_Copy", "複製"},
        {"Mem_ReadFailed", "讀取記憶體失敗"},

        // 刷新
        {"Refresh_Btn", "刷新"},
        {"Refresh_Done", "已刷新"},

        // 工具箱
        {"Toolbox_Title", "工具箱"},
        {"Toolbox_FloatBtn", "工具箱懸浮按鈕"},
        {"Toolbox_FloatBtn_On", "工具箱按鈕已啟用"},
        {"Toolbox_FloatBtn_Off", "工具箱按鈕已停用"},

        // 搜索結果
        {"MemResults_FloatBtn", "結果懸浮按鈕"},
        {"MemResults_FloatBtn_On", "結果按鈕已啟用"},
        {"MemResults_FloatBtn_Off", "結果按鈕已停用"},

        // 記憶體瀏覽器懸浮
        {"MemBrowser_FloatBtn", "瀏覽器懸浮按鈕"},
        {"MemBrowser_FloatBtn_On", "瀏覽器按鈕已啟用"},
        {"MemBrowser_FloatBtn_Off", "瀏覽器按鈕已停用"},

        // 懸浮開關頁面
        {"Float_Desc", "管理懸浮按鈕，快速訪問各功能"},
        {"Float_MemSearch_Desc", "快速打開記憶體搜索"},
        {"Float_Toolbox_Desc", "快速打開工具箱"},
        {"Float_Results_Desc", "快速查看搜索結果"},
        {"Float_Browser_Desc", "快速打開記憶體瀏覽器"},
        {"Float_Position_Hint", "按鈕在右側垂直排列，可拖動調整位置"},

        // 視窗開關頁面
        {"Window_Desc", "顯示/隱藏懸浮視窗"},
        {"Window_MemDebug_Title", "記憶體調試"},
        {"Window_MemDebug_Desc", "記憶體搜尋與分析"},
        {"Window_MemResults_Title", "搜尋結果"},
        {"Window_Toolbox_Desc", "多功能工具箱"},
        {"Window_Browser_Desc", "瀏覽和編輯記憶體"},
        {"Window_Hint", "點擊開關顯示視窗，視窗可收起到螢幕邊緣"},

        // 其他
        {"Script_Untitled", "未命名腳本"},

        // 導入
        {"Btn_Import", "導入"},
        {"Msg_Imported", "已導入 %ld 項"},
        {"Msg_ImportFailed", "導入失敗或格式無效"},

        // Enable/Disable
        {"Msg_Enabled", "已啟用"},
        {"Msg_Disabled", "已停用"},

        // Touch Passthrough Mode
        {"Tool_TouchMode", "觸摸穿透優化"},
        {"Touch_Mode_Desc", "優化連點器相容性"},
        {"Touch_Mode_On", "穿透模式已開啟"},
        {"Touch_Mode_Off", "穿透模式已關閉"},

        // 檔案瀏覽器
        {"FileBrowser_Title", "檔案瀏覽器"},
        {"FileBrowser_Open", "開啟檔案瀏覽器"},
        {"FileBrowser_Back", "← 返回"},
        {"FileBrowser_Import", "匯入檔案"},
        {"FileBrowser_Export", "匯出"},
        {"FileBrowser_Delete", "刪除"},
        {"FileBrowser_DeleteConfirm", "確認刪除？"},
        {"FileBrowser_Deleted", "已刪除"},
        {"FileBrowser_DeleteFail", "刪除失敗"},
        {"FileBrowser_Imported", "已匯入 %ld 個檔案"},
        {"FileBrowser_ImportFail", "匯入失敗"},
        {"FileBrowser_ReadError", "讀取目錄失敗"},
        {"FileBrowser_AtRoot", "已在根目錄"},
        {"FileBrowser_Conflict", "檔案已存在"},
        {"FileBrowser_Overwrite", "覆蓋"},
        {"FileBrowser_Rename", "保留兩者"},
        {"FileBrowser_ImportFolder", "匯入資料夾"},
        {"FileBrowser_ExportFolder", "匯出資料夾 (zip)"},
        {"FileBrowser_OpenFolder", "開啟"},
        {"FileBrowser_Zipping", "壓縮中..."},
        {"FileBrowser_ZipFail", "壓縮失敗"},
        {"FileBrowser_Merge", "合併"},
        {"Window_FileBrowser_Desc", "瀏覽應用程式資料檔案"},

        // 硬體斷點監控
        {"Watch_Title", "斷點監控"},
        {"Watch_Btn", "監控"},
        {"Watch_Add", "新增斷點"},
        {"Watch_Add_Msg", "輸入要監控的記憶體位址"},
        {"Watch_Active", "活躍"},
        {"Watch_Empty", "空閒"},
        {"Watch_Hits", "觸發"},
        {"Watch_Slots", "槽位"},
        {"Watch_ClearAll", "全部清除"},
        {"Watch_ClearAll_Msg", "移除所有斷點和觸發記錄?"},
        {"Watch_Cleared", "已清除所有斷點"},
        {"Watch_Added", "斷點已設置於"},
        {"Watch_Removed", "斷點已移除"},
        {"Watch_Trigger", "觸發點"},
        {"Watch_StackTrace", "呼叫堆疊"},
        {"Watch_HitDetail", "觸發詳情"},
        {"Watch_CopyOffset", "複製偏移量"},
        {"Watch_SendToRVA", "傳送到 RVA"},
        {"Watch_SentToRVA", "已傳送到 RVA 工具箱"},
        {"Watch_JailbreakOnly", "僅限越獄裝置"},
        {"Watch_Err_MaxSlots", "最多 4 個硬體斷點"},
        {"Watch_Err_AddFailed", "斷點設置失敗"},
        {"Watch_Err_InvalidAddr", "無效位址"},
        {"Window_Watch_Desc", "硬體斷點監控"},

        // 代碼檢視器
        {"Inspector_Title", "代碼檢視器"},
        {"Inspector_Patch", "修補"},
        {"Inspector_PatchHint", "HEX (如 C0035FD6)"},
        {"Inspector_Patched", "已修補"},
        {"Inspector_PatchFail", "修補失敗"},
        {"Inspector_NOP", "NOP"},
        {"Inspector_RET", "RET"},
        {"Inspector_ToRVA", "發送到 RVA"},
        {"Inspector_CopyHex", "複製 Hex"},
        {"Inspector_CopyAll", "複製全部"},
        {"Inspector_HexOnly", "僅支援十六進位輸入 (組語請用 armconverter.com)"},
        {"Watch_RVAUpdated", "已更新 RVA 項"},

        // String Browser
        {"Browser_Str_Edit", "編輯字串"},
        {"Browser_Str_OrigLen", "原始長度:"},
        {"Browser_Str_Overflow", "字串溢出"},
        {"Browser_Str_Overflow_Msg", "原始 %lu 位元組，新 %lu 位元組，可能破壞相鄰資料。"},
        {"Browser_Str_Force_Write", "強制寫入"},

        // Icon Picker
        {"Msg_IconChanged", "圖標已更換"},
    };
}
