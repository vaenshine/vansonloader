/**
 * VansonLoader - English Language Pack
 */

#include <map>
#include <string>

std::map<std::string, std::string> getLangEN() {
    return {
        // Tab Labels
        {"Tab_Ptr", "Pointer"},
        {"Tab_RVA", "RVA"},
        {"Tab_Sig", "Signature"},
        {"Tab_Search", "Memory"},
        {"Tab_Tool", "Tools"},
        {"Tab_Assist", "Assist"},
        {"Tab_Window", "Window"},
        {"Tab_About", "About"},
        {"Tab_Mem", "Memory"},
        {"Tab_Fav", "Favorites"},
        {"Tab_Script", "Script"},
        {"Tab_Watch", "Watch"},
        {"Tab_MemBrowser", "Browser"},
        {"Tab_Lock", "Lock"},
        {"Btn_Back", "Back"},

        // Buttons
        {"Btn_Modify", "Edit"},
        {"Btn_Refresh", "Refresh"},
        {"Btn_View", "View"},
        {"Btn_Search", "Search"},
        {"Btn_Scan", "Match"},
        {"Btn_Cancel", "Cancel"},
        {"Btn_Close", "Close"},
        {"Btn_OK", "OK"},
        {"Btn_Edit", "Edit"},
        {"Btn_Delete", "Delete"},
        {"Btn_Done", "Done"},

        // Panel Size
        {"Size_Small", "S"},
        {"Size_Medium", "M"},
        {"Size_Large", "L"},

        // Tools Page
        {"Tool_Clicker", "Auto Clicker"},
        {"Tool_Dump", "Data Export"},
        {"Tool_Config", "Config"},

        // Empty States
        {"Empty_Ptr", "No Pointer Config"},
        {"Empty_RVA", "No RVA Config"},
        {"Empty_Sig", "No Signature Config"},
        {"Empty_Hint", "Tools -> Import Config"},
        {"Empty_Mem", "No Search Results"},
        {"Empty_Mem_Hint", "Use floating button to search"},
        {"Empty_Fav", "No Favorites"},
        {"Empty_Fav_Hint", "Add from memory results"},
        {"Empty_Script", "No Scripts"},
        {"Empty_Script_Hint", "Import .vmsc script files"},

        // Config Management
        {"Config_Import", "Import Config"},
        {"Config_Delete", "Delete Config"},
        {"Config_DeleteConfirm", "Delete current config and clear menu?"},
        {"Config_Deleted", "Config Deleted"},
        {"Config_ImportSuccess", "Imported"},
        {"Config_ImportError", "Invalid format or decryption failed"},

        // Clicker
        {"Click_AddPt", "Add Point"},
        {"Click_Undo", "Undo"},
        {"Click_Start", "Start"},
        {"Click_Stop", "Stop"},
        {"Click_NoPoints", "Add points first"},
        {"Click_Freq", "Freq:"},
        {"Click_Points", "Pts:"},

        // Dump
        {"Dump_Btn", "Dump Unity Metadata + Binary"},

        // RVA Warning
        {"RVA_Warning", "Jailbroken device only"},

        // About Page
        {"About_Title", "VansonLoader"},
        {"About_Telegram", "Telegram @VansonMod"},
        {"About_Lang", "Languages"},
        {"About_Disclaimer", "Disclaimer"},
        {"Disclaimer_Agreed", "Disclaimer Agreed"},
        {"Disclaimer_Tap", "Tap to view"},
        {"Disclaimer_Agree", "I Agree"},
        {"Disclaimer_Reject", "Reject"},
        {"Disclaimer_Rejected", "Rejected, exiting..."},
        {"Disclaimer_Exit", "Exit"},
        {"Disclaimer_Text", "・This project is open source under GPL-3.0 and is intended for security research, reverse engineering learning, and compliant testing.\n\n・Use it in lawful environments and respect applicable rules for target apps and systems.\n\n・Operational risks and legal responsibilities from use are borne by the user.\n\n・By clicking \"I Agree\", you confirm that you have read, understood, and accepted these terms."},
        {"Disclaimer_Content", "・This project is open source under GPL-3.0 and is intended for security research, reverse engineering learning, and compliant testing.\n\n・Use it in lawful environments and respect applicable rules for target apps and systems.\n\n・Operational risks and legal responsibilities from use are borne by the user.\n\n・By clicking \"I Agree\", you confirm that you have read, understood, and accepted these terms."},

        // Toast Messages
        {"Msg_ImportSuccess", "Imported"},
        {"Msg_ImportError", "Invalid format"},
        {"Msg_Locked", "Locked"},
        {"Msg_Unlocked", "Unlocked"},
        {"Msg_Patched", "Patched"},
        {"Msg_Restored", "Restored"},
        {"Msg_WriteFail", "Write Failed"},
        {"Msg_ModuleNotFound", "Module Not Found"},
        {"Msg_Scanning", "Scanning..."},
        {"Msg_ScanComplete", "Scan Complete"},
        {"Msg_NoResult", "No Result"},
        {"Msg_Saved", "Saved"},
        {"Msg_LangChanged", "Language changed"},
        {"Msg_Matched", "Matched"},
        {"Msg_MultiMatch", "matches"},
        {"Msg_UniqueMatch", "Unique match"},
        {"Msg_ClickToScan", "Click Match to search"},
        {"Msg_WriteFailed", "Write Failed"},
        {"Msg_MoreMatches", "+%lu more"},

        // Cell Info
        {"Cell_RVA", "RVA: 0x%llX"},
        {"Cell_Unnamed", "Unnamed"},
        {"Cell_Result", "Result"},

        // Signature
        {"Sig_Addr", "Addr"},

        // Alerts
        {"Alert_Cancel", "Cancel"},
        {"Alert_Confirm", "Confirm"},
        {"Alert_Current", "Current: %@"},

        // Editor
        {"Edit_Title", "Edit Item"},
        {"Edit_Save", "Save"},
        {"Edit_Section_Basic", "Basic Info"},
        {"Edit_Section_UI", "UI Mode"},
        {"Edit_Section_Slider", "Slider Config"},
        {"Edit_Section_Switch", "Switch Config"},
        {"Edit_Note", "Note"},
        {"Edit_Value", "Value"},
        {"Edit_UIMode", "UI Mode"},
        {"Edit_DataType", "Data Type"},
        {"Edit_Author", "Author"},
        {"Edit_Min", "Min"},
        {"Edit_Max", "Max"},
        {"Edit_OnValue", "ON Value"},
        {"Edit_OffValue", "OFF Value"},
        {"Edit_Section_RVA", "RVA Patch"},
        {"Edit_Module", "Framework"},
        {"Edit_Offset", "Offset"},
        {"Edit_PatchHex", "Patch HEX"},
        {"Edit_OrigHex", "Original HEX"},

        // UI Mode
        {"Mode_Card", "Card"},
        {"Mode_Slider", "Slider"},
        {"Mode_Switch", "Switch"},
        {"About_Version", "Version %@"},
        {"About_License", "v3.1: Search Timeline, Snapshot Restore, Write Undo\nOpen Source: GPL-3.0"},

        // Memory Debug (renamed from Memory Search)
        {"Mem_Title", "Memory Search"},
        {"Mem_Debug_Title", "Memory Debug"},
        {"Mem_OpenSearch", "Open Memory Debug"},
        {"Mem_Status", "Search Status"},
        {"Mem_NoResults", "No Results"},
        {"Mem_Exact", "Exact"},
        {"Mem_Fuzzy", "Fuzzy"},
        {"Mem_Range", "Range"},
        {"Mem_InputValue", "Enter search value"},
        {"Mem_Search", "Search"},
        {"Mem_Next", "Next"},
        {"Mem_Reset", "Reset"},
        {"Mem_Ready", "Ready"},
        {"Mem_Empty", "No results yet"},
        {"Mem_Searching", "Searching..."},
        {"Mem_Filtering", "Filtering..."},
        {"Mem_Found", "Found"},
        {"Mem_InputRequired", "Enter a value"},
        {"Mem_LoadMore", "Load More"},
        {"Mem_NoMore", "No more results"},
        {"Mem_NewValue", "New Value"},
        {"Mem_Write", "Write"},
        {"Mem_WriteOK", "Write OK"},
        {"Mem_WriteFail", "Write Failed"},
        {"Mem_Browser", "Browse"},
        {"Mem_Hex", "Hex"},
        {"Mem_Settings", "Settings"},
        {"Mem_FloatTol", "Float Tolerance"},
        {"Mem_GroupRange", "Group Range"},
        {"Mem_TakingSnapshot", "Taking snapshot..."},
        {"Mem_Snapshot_Ready", "Snapshot ready, addresses"},
        {"Mem_Error", "Operation failed"},
        {"Mem_FloatDebug", "Floating Memory Debug"},
        {"Mem_FloatDebug_On", "Enabled"},
        {"Mem_FloatDebug_Off", "Disabled"},
        {"Mem_AddFav", "Add to Favorites"},
        {"Mem_AddedFav", "Added to Favorites"},
        {"Mem_AlreadyFav", "Already in Favorites"},
        {"Mem_RemoveFav", "Remove from Favorites"},
        {"Mem_SendToPanel", "Send to Panel"},
        {"Mem_SentToPanel", "Sent to Panel"},
        {"Mem_CopyAddr", "Copy Address"},
        {"Mem_AutoRefresh_On", "Auto Refresh ON"},
        {"Mem_AutoRefresh_Off", "Auto Refresh OFF"},

        // Fuzzy Search
        {"Fuz_Increased", "Increased"},
        {"Fuz_Decreased", "Decreased"},
        {"Fuz_Unchanged", "Unchanged"},
        {"Fuz_Changed", "Changed"},
        {"Fuz_Inc_Val", "Increased by..."},
        {"Fuz_Dec_Val", "Decreased by..."},
        {"Fuz_Hint_Increased", "Filter addresses where value increased"},
        {"Fuz_Hint_Decreased", "Filter addresses where value decreased"},
        {"Fuz_Hint_Unchanged", "Filter addresses where value unchanged"},
        {"Fuz_Hint_Changed", "Filter addresses where value changed"},
        {"Fuz_Hint_Inc_Val", "Filter addresses increased by value"},
        {"Fuz_Hint_Dec_Val", "Filter addresses decreased by value"},
        {"Fuz_Input_Delta", "Enter delta value"},
        {"Fuz_Select_Mode", "Select filter mode"},
        {"Fuz_Search_OK", "Search successful, change value then continue searching"},
        {"Fuz_Unchanged_TooMany", "Too many results, narrow down first"},
        {"Fuz_First_Hint", "Click search to start"},

        // Filter Panel
        {"Filter_Btn", "Filter"},
        {"Filter_Less", "Less"},
        {"Filter_Greater", "Greater"},
        {"Filter_Between", "Between"},
        {"Filter_Apply", "Apply"},
        {"Filter_Input_Min", "Min"},
        {"Filter_Input_Max", "Max"},
        {"Filter_Input_Val", "Value"},

        // Nearby Search
        {"Nearby_Btn", "Nearby"},
        {"Nearby_Title", "Nearby Search"},
        {"Nearby_Range", "Range (bytes)"},
        {"Nearby_Value", "Target Value"},

        // Refresh
        {"Refresh_Btn", "Refresh"},
        {"Refresh_Done", "Refreshed"},

        // Batch Operations
        {"Batch_Btn", "Batch"},
        {"Batch_Modify", "Batch Modify"},
        {"Batch_Modify_Hint", "Modify first %lu results"},
        {"Batch_Copy", "Copy Addresses"},
        {"Batch_Copied", "Copied %lu addresses"},
        {"Batch_Modified", "Modified %lu addresses"},
        {"Batch_Select", "Select"},
        {"Batch_Action", "Batch"},
        {"Batch_NoSelection", "No address selected"},
        {"Batch_Selected_Count", "%lu selected"},
        {"Batch_Fixed", "Set Fixed Value"},
        {"Batch_Increment", "Increment Values"},
        {"Batch_Start_Value", "Start value"},
        {"Batch_Select_All", "Select Visible"},
        {"Batch_Exit_Select", "Exit Select"},

        // Script
        {"Script_Run", "Run Script"},
        {"Script_ViewSource", "View Source"},
        {"Script_Running", "Running script..."},
        {"Script_Empty", "Script content is empty"},
        {"Script_Done", "Script completed"},

        // UI Text (replaced emojis)
        {"UI_Lock", "Lock"},
        {"UI_Unlock", "Unlock"},
        {"UI_Locked", "[Lock]"},
        {"UI_Unlocked", "Lock"},
        {"UI_Fav", "Fav"},
        {"UI_Unfav", "Unfav"},
        {"UI_Faved", "[Fav]"},
        {"UI_Unfaved", "Fav"},
        {"UI_View", "View"},
        {"UI_Close", "X"},

        // Memory Search Tabs
        {"Mem_Tab_Exact", "Exact"},
        {"Mem_Tab_Fuzzy", "Fuzzy"},
        {"Mem_Tab_Group", "Group"},

        {"Timeline_Title", "Search Timeline"},
        {"Timeline_Empty", "No search snapshots"},
        {"Timeline_Clear", "Clear Timeline"},
        {"Timeline_Restored_Fmt", "Restored %@ · %lu results"},
        {"Timeline_Restore_Failed", "Restore failed"},
        {"Timeline_Mode_Exact", "Exact Search"},
        {"Timeline_Mode_Fuzzy", "Fuzzy Search"},
        {"Timeline_Mode_Group", "Group Search"},
        {"Timeline_Mode_Between", "Range Search"},
        {"Undo_Last_Modify", "Undo Last Modify"},
        {"Undo_Success", "Modify undone"},
        {"Undo_Failed", "Undo failed"},

        // Memory Search Additional
        {"Mem_GroupHint", "Use ; or :: to separate values"},
        {"Mem_BetweenHint", "Range search: enter min~max or min-max"},
        {"Err_Not_Numeric", "Please enter a valid number"},
        {"Err_Range_Invalid", "Invalid range format"},
        {"Mem_Copied", "Copied"},
        {"Mem_Actions", "Actions"},
        {"Mem_Browse", "Browse Memory"},
        {"Mem_HexView", "Hex View"},

        // Group Search Help
        {"Group_Help_Title", "Group Search Guide"},
        {"Group_Help_Msg", "Search multiple values in memory order.\n\n1. Basic (use current type):\n   100; 200; 300\n   (Values must appear in this order)\n\n2. Mixed types (value+type):\n   100 i32; 0.5 f32; 10 i8\n   (Supports: i8, i16, i32, i64, f32, f64)\n\n3. Specify range (add :: at end):\n   10; 20::100\n   (Next value within 100 bytes)\n\n4. Separators:\n   Semicolon (;) or space recommended"},

        // Memory Results Panel
        {"Mem_Results", "Results"},

        // Toolbox
        {"Toolbox_Title", "Toolbox"},
        {"Toolbox_FloatBtn", "Toolbox Float Button"},
        {"Toolbox_FloatBtn_On", "Toolbox Button Enabled"},
        {"Toolbox_FloatBtn_Off", "Toolbox Button Disabled"},

        // Memory Results
        {"MemResults_FloatBtn", "Results Float Button"},
        {"MemResults_FloatBtn_On", "Results Button Enabled"},
        {"MemResults_FloatBtn_Off", "Results Button Disabled"},

        // Memory Browser Float
        {"MemBrowser_FloatBtn", "Browser Float Button"},
        {"MemBrowser_FloatBtn_On", "Browser Button Enabled"},
        {"MemBrowser_FloatBtn_Off", "Browser Button Disabled"},

        // Window Switches Page
        {"Window_Desc", "Show/hide floating windows"},
        {"Window_MemDebug_Title", "Memory Debug"},
        {"Window_MemDebug_Desc", "Memory search and analysis"},
        {"Window_MemResults_Title", "Search Results"},
        {"Window_Toolbox_Desc", "Toolbox with multiple features"},
        {"Window_Browser_Desc", "Browse and edit memory"},
        {"Window_Hint", "Click switch to show window. Windows can be minimized to edge."},

        // Memory Browser
        {"Mem_Browser_Title", "Memory Browser"},
        {"Mem_Hex_Title", "Hex Editor"},
        {"Mem_Go", "Go"},
        {"Mem_NextPage", "Next"},
        {"Mem_PrevPage", "Prev"},
        {"Mem_Copy", "Copy"},
        {"Mem_ReadFailed", "Failed to read memory"},

        // Script
        {"Script_Untitled", "Untitled Script"},

        // Import
        {"Btn_Import", "Import"},
        {"Msg_Imported", "Imported %ld items"},
        {"Msg_ImportFailed", "Import failed or invalid format"},

        // Enable/Disable
        {"Msg_Enabled", "Enabled"},
        {"Msg_Disabled", "Disabled"},

        // Touch Passthrough Mode
        {"Tool_TouchMode", "Touch Passthrough Opt"},
        {"Touch_Mode_Desc", "Optimize for auto-clicker compatibility"},
        {"Touch_Mode_On", "Passthrough Mode ON"},
        {"Touch_Mode_Off", "Passthrough Mode OFF"},

        // File Browser
        {"FileBrowser_Title", "File Browser"},
        {"FileBrowser_Open", "Open File Browser"},
        {"FileBrowser_Back", "← Back"},
        {"FileBrowser_Import", "Import File"},
        {"FileBrowser_Export", "Export"},
        {"FileBrowser_Delete", "Delete"},
        {"FileBrowser_DeleteConfirm", "Confirm delete?"},
        {"FileBrowser_Deleted", "Deleted"},
        {"FileBrowser_DeleteFail", "Delete failed"},
        {"FileBrowser_Imported", "Imported %ld files"},
        {"FileBrowser_ImportFail", "Import failed"},
        {"FileBrowser_ReadError", "Failed to read directory"},
        {"FileBrowser_AtRoot", "Already at root directory"},
        {"FileBrowser_Conflict", "File already exists"},
        {"FileBrowser_Overwrite", "Overwrite"},
        {"FileBrowser_Rename", "Keep Both"},
        {"FileBrowser_ImportFolder", "Import Folder"},
        {"FileBrowser_ExportFolder", "Export Folder (zip)"},
        {"FileBrowser_OpenFolder", "Open"},
        {"FileBrowser_Zipping", "Compressing..."},
        {"FileBrowser_ZipFail", "Compression failed"},
        {"FileBrowser_Merge", "Merge"},
        {"Window_FileBrowser_Desc", "Browse app data files"},

        // Hardware Watchpoint
        {"Watch_Title", "Watchpoint Monitor"},
        {"Watch_Btn", "Watch"},
        {"Watch_Add", "Add Watchpoint"},
        {"Watch_Add_Msg", "Enter memory address to monitor"},
        {"Watch_Active", "Active"},
        {"Watch_Empty", "Empty"},
        {"Watch_Hits", "Hits"},
        {"Watch_Slots", "Slots"},
        {"Watch_ClearAll", "Clear All"},
        {"Watch_ClearAll_Msg", "Remove all watchpoints and hit records?"},
        {"Watch_Cleared", "All watchpoints cleared"},
        {"Watch_Added", "Watchpoint set at"},
        {"Watch_Removed", "Watchpoint removed"},
        {"Watch_Trigger", "Triggered"},
        {"Watch_StackTrace", "Stack Trace"},
        {"Watch_HitDetail", "Hit Detail"},
        {"Watch_CopyOffset", "Copy Offset"},
        {"Watch_SendToRVA", "Send to RVA"},
        {"Watch_SentToRVA", "Sent to RVA toolbox"},
        {"Watch_JailbreakOnly", "Jailbroken device only"},
        {"Watch_Err_MaxSlots", "Max 4 hardware watchpoints"},
        {"Watch_Err_AddFailed", "Failed to set watchpoint"},
        {"Watch_Err_InvalidAddr", "Invalid address"},
        {"Window_Watch_Desc", "Hardware breakpoint monitor"},

        // Code Inspector
        {"Inspector_Title", "Code Inspector"},
        {"Inspector_Patch", "Patch"},
        {"Inspector_PatchHint", "HEX (e.g. C0035FD6)"},
        {"Inspector_Patched", "Patched"},
        {"Inspector_PatchFail", "Patch failed"},
        {"Inspector_NOP", "NOP"},
        {"Inspector_RET", "RET"},
        {"Inspector_ToRVA", "To RVA"},
        {"Inspector_CopyHex", "Copy Hex"},
        {"Inspector_CopyAll", "Copy All"},
        {"Inspector_HexOnly", "Hex input only (use armconverter.com for ASM)"},
        {"Watch_RVAUpdated", "RVA item updated"},

        // String Browser
        {"Browser_Str_Edit", "Edit String"},
        {"Browser_Str_OrigLen", "Original length:"},
        {"Browser_Str_Overflow", "String Overflow"},
        {"Browser_Str_Overflow_Msg", "Original %lu bytes, new %lu bytes. May corrupt adjacent data."},
        {"Browser_Str_Force_Write", "Force Write"},

        // Icon Picker
        {"Msg_IconChanged", "Icon changed"},
    };
}
