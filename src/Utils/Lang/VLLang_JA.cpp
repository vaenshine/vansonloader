/**
 * VansonLoader - 日本語言語パック
 */

#include <map>
#include <string>

std::map<std::string, std::string> getLangJA() {
    return {
        // タブラベル
        {"Tab_Ptr", "ポインタ"},
        {"Tab_RVA", "RVA"},
        {"Tab_Sig", "シグネチャ"},
        {"Tab_Search", "メモリ"},
        {"Tab_Tool", "ツール"},
        {"Tab_Assist", "補助"},
        {"Tab_Window", "ウィンドウ"},
        {"Tab_About", "情報"},
        {"Tab_Mem", "メモリ"},
        {"Tab_Fav", "お気に入り"},
        {"Tab_Script", "スクリプト"},
        {"Tab_Watch", "監視"},
        {"Tab_MemBrowser", "ブラウザ"},
        {"Tab_Lock", "ロック"},
        {"Btn_Back", "戻る"},

        // ボタン
        {"Btn_Modify", "編集"},
        {"Btn_Refresh", "更新"},
        {"Btn_View", "表示"},
        {"Btn_Search", "検索"},
        {"Btn_Scan", "マッチ"},
        {"Btn_Cancel", "キャンセル"},
        {"Btn_Close", "閉じる"},
        {"Btn_OK", "OK"},
        {"Btn_Edit", "編集"},
        {"Btn_Delete", "削除"},
        {"Btn_Done", "完了"},

        // パネルサイズ
        {"Size_Small", "小"},
        {"Size_Medium", "中"},
        {"Size_Large", "大"},

        // ツールページ
        {"Tool_Clicker", "オートクリッカー"},
        {"Tool_Dump", "データエクスポート"},
        {"Tool_Config", "設定"},

        // 空の状態
        {"Empty_Ptr", "ポインタ設定なし"},
        {"Empty_RVA", "RVA設定なし"},
        {"Empty_Sig", "シグネチャ設定なし"},
        {"Empty_Hint", "ツール -> 設定をインポート"},
        {"Empty_Mem", "検索結果なし"},
        {"Empty_Mem_Hint", "フローティングボタンで検索"},
        {"Empty_Fav", "お気に入りなし"},
        {"Empty_Fav_Hint", "メモリ結果から追加"},
        {"Empty_Script", "スクリプトなし"},
        {"Empty_Script_Hint", ".vmscファイルをインポート"},

        // 設定管理
        {"Config_Import", "設定をインポート"},
        {"Config_Delete", "設定を削除"},
        {"Config_DeleteConfirm", "現在の設定を削除してメニューをクリアしますか？"},
        {"Config_Deleted", "設定を削除しました"},
        {"Config_ImportSuccess", "インポート完了"},
        {"Config_ImportError", "形式エラーまたは復号失敗"},

        // クリッカー
        {"Click_AddPt", "ポイント追加"},
        {"Click_Undo", "元に戻す"},
        {"Click_Start", "開始"},
        {"Click_Stop", "停止"},
        {"Click_NoPoints", "先にポイントを追加してください"},
        {"Click_Freq", "間隔:"},
        {"Click_Points", "点数:"},

        // Dump
        {"Dump_Btn", "Unity Metadata + Binary をダンプ"},

        // RVA 警告
        {"RVA_Warning", "脱獄デバイスのみ"},

        // 情報ページ
        {"About_Title", "VansonLoader"},
        {"About_Telegram", "Telegram @VansonMod"},
        {"About_Lang", "Languages"},
        {"About_Disclaimer", "免責事項"},
        {"Disclaimer_Agreed", "免責事項に同意済み"},
        {"Disclaimer_Tap", "タップして表示"},
        {"Disclaimer_Agree", "同意する"},
        {"Disclaimer_Reject", "拒否"},
        {"Disclaimer_Rejected", "拒否しました、終了中..."},
        {"Disclaimer_Exit", "終了"},
        {"Disclaimer_Text", "・This project is open source under GPL-3.0 and is intended for security research, reverse engineering learning, and compliant testing.\n\n・Use it in lawful environments and respect applicable rules for target apps and systems.\n\n・Operational risks and legal responsibilities from use are borne by the user."},
        {"Disclaimer_Content", "・This project is open source under GPL-3.0 and is intended for security research, reverse engineering learning, and compliant testing.\n\n・Use it in lawful environments and respect applicable rules for target apps and systems.\n\n・Operational risks and legal responsibilities from use are borne by the user."},

        // トーストメッセージ
        {"Msg_ImportSuccess", "インポート完了"},
        {"Msg_ImportError", "形式エラー"},
        {"Msg_Locked", "ロック済み"},
        {"Msg_Unlocked", "ロック解除"},
        {"Msg_Patched", "パッチ適用済み"},
        {"Msg_Restored", "復元済み"},
        {"Msg_WriteFail", "書き込み失敗"},
        {"Msg_ModuleNotFound", "モジュールが見つかりません"},
        {"Msg_Scanning", "スキャン中..."},
        {"Msg_ScanComplete", "スキャン完了"},
        {"Msg_NoResult", "結果なし"},
        {"Msg_Saved", "保存済み"},
        {"Msg_LangChanged", "言語を変更しました"},
        {"Msg_Matched", "マッチ成功"},
        {"Msg_MultiMatch", "件マッチ"},
        {"Msg_UniqueMatch", "一意のマッチ"},
        {"Msg_ClickToScan", "マッチボタンをクリックして検索"},
        {"Msg_WriteFailed", "書き込み失敗"},
        {"Msg_MoreMatches", "+%lu 件"},

        // セル情報
        {"Cell_RVA", "RVA: 0x%llX"},
        {"Cell_Unnamed", "名前なし"},
        {"Cell_Result", "結果"},

        // シグネチャ
        {"Sig_Addr", "アドレス"},

        // アラート
        {"Alert_Cancel", "キャンセル"},
        {"Alert_Confirm", "確認"},
        {"Alert_Current", "現在値: %@"},

        // エディタ
        {"Edit_Title", "項目を編集"},
        {"Edit_Save", "保存"},
        {"Edit_Section_Basic", "基本情報"},
        {"Edit_Section_UI", "UIモード"},
        {"Edit_Section_Slider", "スライダー設定"},
        {"Edit_Section_Switch", "スイッチ設定"},
        {"Edit_Note", "メモ"},
        {"Edit_Value", "値"},
        {"Edit_UIMode", "UIモード"},
        {"Edit_DataType", "データ型"},
        {"Edit_Author", "作者"},
        {"Edit_Min", "最小値"},
        {"Edit_Max", "最大値"},
        {"Edit_OnValue", "ON値"},
        {"Edit_OffValue", "OFF値"},
        {"Edit_Section_RVA", "RVA パッチ"},
        {"Edit_Module", "フレームワーク"},
        {"Edit_Offset", "オフセット"},
        {"Edit_PatchHex", "パッチ HEX"},
        {"Edit_OrigHex", "元の HEX"},

        // UIモード
        {"Mode_Card", "カード"},
        {"Mode_Slider", "スライダー"},
        {"Mode_Switch", "スイッチ"},
        {"About_Version", "バージョン %@"},
        {"About_License", "v3.1: Search Timeline, Snapshot Restore, Write Undo\nOpen Source: GPL-3.0"},

        // メモリ検索
        {"Mem_Title", "メモリ検索"},
        {"Mem_Debug_Title", "メモリデバッグ"},
        {"Mem_OpenSearch", "メモリデバッグを開く"},
        {"Mem_Status", "検索状態"},
        {"Mem_NoResults", "結果なし"},
        {"Mem_Exact", "完全一致"},
        {"Mem_Fuzzy", "あいまい"},
        {"Mem_Range", "範囲"},
        {"Mem_InputValue", "検索値を入力"},
        {"Mem_Search", "検索"},
        {"Mem_Next", "次へ"},
        {"Mem_Reset", "リセット"},
        {"Mem_Ready", "準備完了"},
        {"Mem_Empty", "結果なし"},
        {"Mem_Searching", "検索中..."},
        {"Mem_Filtering", "フィルタリング中..."},
        {"Mem_Found", "見つかりました"},
        {"Mem_InputRequired", "値を入力してください"},
        {"Mem_LoadMore", "もっと読み込む"},
        {"Mem_NoMore", "これ以上ありません"},
        {"Mem_NewValue", "新しい値"},
        {"Mem_Write", "書き込み"},
        {"Mem_WriteOK", "書き込み成功"},
        {"Mem_WriteFail", "書き込み失敗"},
        {"Mem_Browser", "ブラウズ"},
        {"Mem_Hex", "Hex"},
        {"Mem_Settings", "設定"},
        {"Mem_FloatTol", "浮動小数点許容差"},
        {"Mem_GroupRange", "グループ範囲"},
        {"Mem_TakingSnapshot", "スナップショット作成中..."},
        {"Mem_Snapshot_Ready", "スナップショット準備完了、アドレス数"},
        {"Mem_Error", "操作失敗"},
        {"Mem_FloatDebug", "フローティングメモリデバッグ"},
        {"Mem_FloatDebug_On", "有効"},
        {"Mem_FloatDebug_Off", "無効"},
        {"Mem_AddFav", "お気に入りに追加"},
        {"Mem_AddedFav", "お気に入りに追加しました"},
        {"Mem_AlreadyFav", "すでにお気に入りです"},
        {"Mem_RemoveFav", "お気に入りから削除"},
        {"Mem_SendToPanel", "パネルに送信"},
        {"Mem_SentToPanel", "パネルに送信しました"},
        {"Mem_CopyAddr", "アドレスをコピー"},
        {"Mem_AutoRefresh_On", "自動更新ON"},
        {"Mem_AutoRefresh_Off", "自動更新OFF"},

        // あいまい検索
        {"Fuz_Increased", "増加"},
        {"Fuz_Decreased", "減少"},
        {"Fuz_Unchanged", "変化なし"},
        {"Fuz_Changed", "変化あり"},
        {"Fuz_Inc_Val", "増加量..."},
        {"Fuz_Dec_Val", "減少量..."},
        {"Fuz_Hint_Increased", "値が増加したアドレスをフィルタ"},
        {"Fuz_Hint_Decreased", "値が減少したアドレスをフィルタ"},
        {"Fuz_Hint_Unchanged", "値が変化していないアドレスをフィルタ"},
        {"Fuz_Hint_Changed", "値が変化したアドレスをフィルタ"},
        {"Fuz_Hint_Inc_Val", "指定値だけ増加したアドレスをフィルタ"},
        {"Fuz_Hint_Dec_Val", "指定値だけ減少したアドレスをフィルタ"},
        {"Fuz_Input_Delta", "変化量を入力"},
        {"Fuz_Select_Mode", "フィルタモードを選択"},
        {"Fuz_Search_OK", "検索成功、値を変更して検索を続行"},
        {"Fuz_Unchanged_TooMany", "結果が多すぎます、先に絞り込んでください"},
        {"Fuz_First_Hint", "検索をクリックして開始"},

        // フィルタパネル
        {"Filter_Btn", "フィルタ"},
        {"Filter_Less", "未満"},
        {"Filter_Greater", "超過"},
        {"Filter_Between", "範囲"},
        {"Filter_Apply", "適用"},
        {"Filter_Input_Min", "最小値"},
        {"Filter_Input_Max", "最大値"},
        {"Filter_Input_Val", "値"},

        // 近傍検索
        {"Nearby_Btn", "近傍"},
        {"Nearby_Title", "近傍検索"},
        {"Nearby_Range", "範囲（バイト）"},
        {"Nearby_Value", "目標値"},

        // 更新
        {"Refresh_Btn", "更新"},

        // バッチ操作
        {"Batch_Btn", "バッチ"},
        {"Batch_Modify", "バッチ修正"},
        {"Batch_Modify_Hint", "最初の%lu件を修正"},
        {"Batch_Copy", "アドレスをコピー"},
        {"Batch_Copied", "%lu件のアドレスをコピーしました"},
        {"Batch_Modified", "%lu件のアドレスを修正しました"},

        // スクリプト
        {"Script_Run", "スクリプト実行"},
        {"Script_ViewSource", "ソースを表示"},
        {"Script_Running", "スクリプト実行中..."},
        {"Script_Empty", "スクリプトが空です"},
        {"Script_Done", "スクリプト完了"},

        // UI テキスト (絵文字置換)
        {"UI_Lock", "ロック"},
        {"UI_Unlock", "解除"},
        {"UI_Locked", "[L]"},
        {"UI_Unlocked", "L"},
        {"UI_Fav", "お気に入り"},
        {"UI_Unfav", "解除"},
        {"UI_Faved", "[F]"},
        {"UI_Unfaved", "F"},
        {"UI_View", "表示"},
        {"UI_Close", "X"},

        // メモリ検索タブ
        {"Mem_Tab_Exact", "完全一致"},
        {"Mem_Tab_Fuzzy", "あいまい"},
        {"Mem_Tab_Group", "グループ"},

        {"Timeline_Title", "検索タイムライン"},
        {"Timeline_Empty", "検索スナップショットなし"},
        {"Timeline_Clear", "タイムラインをクリア"},
        {"Timeline_Restored_Fmt", "%@ に復元 · %lu件"},
        {"Timeline_Restore_Failed", "復元失敗"},
        {"Timeline_Mode_Exact", "完全検索"},
        {"Timeline_Mode_Fuzzy", "あいまい検索"},
        {"Timeline_Mode_Group", "グループ検索"},
        {"Timeline_Mode_Between", "範囲検索"},
        {"Undo_Last_Modify", "前回の変更を元に戻す"},
        {"Undo_Success", "変更を元に戻しました"},
        {"Undo_Failed", "元に戻せませんでした"},

        // メモリ検索追加
        {"Mem_GroupHint", "; または :: で値を区切る"},
        {"Mem_BetweenHint", "範囲検索: 最小値~最大値 または 最小値-最大値"},
        {"Err_Not_Numeric", "有効な数値を入力してください"},
        {"Err_Range_Invalid", "範囲の形式が無効です"},
        {"Mem_Copied", "コピーしました"},
        {"Mem_Actions", "操作"},
        {"Mem_Browse", "メモリブラウズ"},
        {"Mem_HexView", "Hex表示"},

        // グループ検索ヘルプ
        {"Group_Help_Title", "グループ検索ガイド"},
        {"Group_Help_Msg", "メモリ順序で複数の値を検索します。\n\n1. 基本（現在のタイプを使用）:\n   100; 200; 300\n   （値はこの順序で表示される必要があります）\n\n2. 混合タイプ（値+タイプ）:\n   100 i32; 0.5 f32; 10 i8\n   （サポート: i8, i16, i32, i64, f32, f64）\n\n3. 範囲を指定（末尾に :: を追加）:\n   10; 20::100\n   （次の値は100バイト以内）\n\n4. 区切り文字:\n   セミコロン (;) またはスペースを推奨"},

        // 結果パネル
        {"Mem_Results", "検索結果"},

        // メモリブラウザ
        {"Mem_Browser_Title", "メモリブラウザ"},
        {"Mem_Hex_Title", "Hexエディタ"},
        {"Mem_Go", "移動"},
        {"Mem_NextPage", "次へ"},
        {"Mem_PrevPage", "前へ"},
        {"Mem_Copy", "コピー"},
        {"Mem_ReadFailed", "メモリ読み取り失敗"},

        // 刷新
        {"Refresh_Btn", "更新"},
        {"Refresh_Done", "更新完了"},

        // ツールボックス
        {"Toolbox_Title", "ツールボックス"},
        {"Toolbox_FloatBtn", "ツールボックスフローティングボタン"},
        {"Toolbox_FloatBtn_On", "ツールボックスボタン有効"},
        {"Toolbox_FloatBtn_Off", "ツールボックスボタン無効"},

        // 検索結果
        {"MemResults_FloatBtn", "結果フローティングボタン"},
        {"MemResults_FloatBtn_On", "結果ボタン有効"},
        {"MemResults_FloatBtn_Off", "結果ボタン無効"},

        // メモリブラウザフロート
        {"MemBrowser_FloatBtn", "ブラウザフローティングボタン"},
        {"MemBrowser_FloatBtn_On", "ブラウザボタン有効"},
        {"MemBrowser_FloatBtn_Off", "ブラウザボタン無効"},

        // フロートスイッチページ
        {"Float_Desc", "フローティングボタンを管理"},
        {"Float_MemSearch_Desc", "メモリ検索を素早く開く"},
        {"Float_Toolbox_Desc", "ツールボックスを素早く開く"},
        {"Float_Results_Desc", "検索結果を素早く表示"},
        {"Float_Browser_Desc", "メモリブラウザを素早く開く"},
        {"Float_Position_Hint", "ボタンは右側に縦に配置、ドラッグで移動可能"},

        // ウィンドウスイッチページ
        {"Window_Desc", "フローティングウィンドウの表示/非表示"},
        {"Window_MemDebug_Title", "メモリデバッグ"},
        {"Window_MemDebug_Desc", "メモリ検索と分析"},
        {"Window_MemResults_Title", "検索結果"},
        {"Window_Toolbox_Desc", "多機能ツールボックス"},
        {"Window_Browser_Desc", "メモリの閲覧と編集"},
        {"Window_Hint", "スイッチをクリックしてウィンドウを表示。ウィンドウは端に最小化可能。"},

        // その他
        {"Script_Untitled", "無題のスクリプト"},

        // インポート
        {"Btn_Import", "インポート"},
        {"Msg_Imported", "%ld 件インポートしました"},
        {"Msg_ImportFailed", "インポート失敗または無効な形式"},

        // Enable/Disable
        {"Msg_Enabled", "有効"},
        {"Msg_Disabled", "無効"},

        // Touch Passthrough Mode
        {"Tool_TouchMode", "タッチ透過最適化"},
        {"Touch_Mode_Desc", "オートクリッカー互換性を最適化"},
        {"Touch_Mode_On", "透過モードON"},
        {"Touch_Mode_Off", "透過モードOFF"},

        // ファイルブラウザ
        {"FileBrowser_Title", "ファイルブラウザ"},
        {"FileBrowser_Open", "ファイルブラウザを開く"},
        {"FileBrowser_Back", "← 戻る"},
        {"FileBrowser_Import", "ファイルをインポート"},
        {"FileBrowser_Export", "エクスポート"},
        {"FileBrowser_Delete", "削除"},
        {"FileBrowser_DeleteConfirm", "削除しますか？"},
        {"FileBrowser_Deleted", "削除しました"},
        {"FileBrowser_DeleteFail", "削除に失敗"},
        {"FileBrowser_Imported", "%ld 件インポートしました"},
        {"FileBrowser_ImportFail", "インポートに失敗"},
        {"FileBrowser_ReadError", "ディレクトリの読み取りに失敗"},
        {"FileBrowser_AtRoot", "ルートディレクトリです"},
        {"FileBrowser_Conflict", "ファイルが既に存在します"},
        {"FileBrowser_Overwrite", "上書き"},
        {"FileBrowser_Rename", "両方保持"},
        {"FileBrowser_ImportFolder", "フォルダ読込"},
        {"FileBrowser_ExportFolder", "フォルダ書出 (zip)"},
        {"FileBrowser_OpenFolder", "開く"},
        {"FileBrowser_Zipping", "圧縮中..."},
        {"FileBrowser_ZipFail", "圧縮失敗"},
        {"FileBrowser_Merge", "マージ"},
        {"Window_FileBrowser_Desc", "アプリデータファイルを閲覧"},

        // ハードウェアウォッチポイント
        {"Watch_Title", "ウォッチポイント"},
        {"Watch_Btn", "監視"},
        {"Watch_Add", "ウォッチポイント追加"},
        {"Watch_Add_Msg", "監視するメモリアドレスを入力"},
        {"Watch_Active", "アクティブ"},
        {"Watch_Empty", "空き"},
        {"Watch_Hits", "ヒット"},
        {"Watch_Slots", "スロット"},
        {"Watch_ClearAll", "全削除"},
        {"Watch_ClearAll_Msg", "全てのウォッチポイントと記録を削除?"},
        {"Watch_Cleared", "全てのウォッチポイントを削除しました"},
        {"Watch_Added", "ウォッチポイント設定"},
        {"Watch_Removed", "ウォッチポイント削除"},
        {"Watch_Trigger", "トリガー"},
        {"Watch_StackTrace", "コールスタック"},
        {"Watch_HitDetail", "ヒット詳細"},
        {"Watch_CopyOffset", "オフセットをコピー"},
        {"Watch_SendToRVA", "RVA に送信"},
        {"Watch_SentToRVA", "RVA ツールボックスに送信しました"},
        {"Watch_JailbreakOnly", "脱獄デバイスのみ"},
        {"Watch_Err_MaxSlots", "ハードウェアウォッチポイントは最大4個"},
        {"Watch_Err_AddFailed", "ウォッチポイント設定失敗"},
        {"Watch_Err_InvalidAddr", "無効なアドレス"},
        {"Window_Watch_Desc", "ハードウェアブレークポイント監視"},

        // コードインスペクター
        {"Inspector_Title", "コードインスペクター"},
        {"Inspector_Patch", "パッチ"},
        {"Inspector_PatchHint", "HEX (例: C0035FD6)"},
        {"Inspector_Patched", "パッチ適用済み"},
        {"Inspector_PatchFail", "パッチ失敗"},
        {"Inspector_NOP", "NOP"},
        {"Inspector_RET", "RET"},
        {"Inspector_ToRVA", "RVAへ送信"},
        {"Inspector_CopyHex", "Hexコピー"},
        {"Inspector_CopyAll", "全てコピー"},
        {"Inspector_HexOnly", "16進数入力のみ (ASMはarmconverter.comを使用)"},
        {"Watch_RVAUpdated", "RVA項目を更新しました"},

        // String Browser
        {"Browser_Str_Edit", "文字列を編集"},
        {"Browser_Str_OrigLen", "元の長さ:"},
        {"Browser_Str_Overflow", "文字列オーバーフロー"},
        {"Browser_Str_Overflow_Msg", "元 %lu バイト、新 %lu バイト。隣接データを破損する可能性があります。"},
        {"Browser_Str_Force_Write", "強制書き込み"},

        // Icon Picker
        {"Msg_IconChanged", "アイコンが変更されました"},
    };
}
