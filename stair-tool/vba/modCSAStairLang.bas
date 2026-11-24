Attribute VB_Name = "modCSAStairLang"
Option Explicit

' Bilingual EN / VI UI localization helper for frmCSAStair and GDI previews.
' All Vietnamese Unicode characters are constructed via ChrW$ so this file
' remains 100% pure 7-bit ASCII and imports cleanly on any Windows locale.

Public Const CSA_LANG_EN As String = "EN"
Public Const CSA_LANG_VI As String = "VI"

Public gCSALanguage As String

Public Function CSA_CurrentLang() As String
    If gCSALanguage <> CSA_LANG_VI Then
        CSA_CurrentLang = CSA_LANG_EN
    Else
        CSA_CurrentLang = CSA_LANG_VI
    End If
End Function

Public Sub CSA_SetLanguage(ByVal langCode As String)
    If UCase$(Trim$(langCode)) = CSA_LANG_VI Then
        gCSALanguage = CSA_LANG_VI
    Else
        gCSALanguage = CSA_LANG_EN
    End If
End Sub

Public Function CSA_Tr(ByVal key As String) As String
    If CSA_CurrentLang() = CSA_LANG_VI Then
        CSA_Tr = TranslateVi(key)
    Else
        CSA_Tr = TranslateEn(key)
    End If
End Function

Private Function TranslateEn(ByVal key As String) As String
    Select Case key
        Case "EN_NAME": TranslateEn = "English"
        Case "VI_NAME": TranslateEn = "Ti" & ChrW$(&H1EBF) & "ng Vi" & ChrW$(&H1EC7) & "t"
        Case "TITLE": TranslateEn = "Stair Drawing"
        Case "SUBTITLE": TranslateEn = "CSA TOOLS  |  STAIR DRAWING"
        Case "HDR_PARAMS": TranslateEn = "  Stair Parameters"
        Case "HDR_PREVIEW": TranslateEn = "  Preview"
        Case "HDR_OPTIONS": TranslateEn = "  Options"
        Case "TAB_GENERAL": TranslateEn = "General"
        Case "TAB_PLAN_CAD": TranslateEn = "Plan & CAD"
        Case "TAB_SECTION": TranslateEn = "Section View"
        Case "TAB_PLAN": TranslateEn = "Plan View"
        Case "STAIR_NAME": TranslateEn = "Stair Name:"
        Case "STAIR_TYPE": TranslateEn = "Stair Type:"
        Case "TYPE_2F": TranslateEn = "Two Flight (With Landing)"
        Case "TYPE_3F": TranslateEn = "Three Flight"
        Case "TYPE_1F": TranslateEn = "Single Flight"
        Case "WIDTH": TranslateEn = "Width (mm):"
        Case "BOT_ELEV": TranslateEn = "Bottom Elev.:"
        Case "TOP_ELEV": TranslateEn = "Top Elev.:"
        Case "RISER": TranslateEn = "Riser (mm):"
        Case "TREAD": TranslateEn = "Tread (mm):"
        Case "SLAB": TranslateEn = "Slab Thick. (mm):"
        Case "SCALE": TranslateEn = "Scale:"
        Case "FLIGHT1": TranslateEn = "Flight 1 Risers:"
        Case "FLIGHT2": TranslateEn = "Flight 2 Risers:"
        Case "FLIGHT3": TranslateEn = "Flight 3 Risers:"
        Case "MID_LAND": TranslateEn = "Mid Landing (mm):"
        Case "UP_LAND": TranslateEn = "Upper Landing:"
        Case "WELL_GAP": TranslateEn = "Well Gap (mm):"
        Case "SUP_WIDTH": TranslateEn = "Support Width:"
        Case "DIR": TranslateEn = "Start Direction:"
        Case "SEC_MARK": TranslateEn = "Section Mark:"
        Case "DIMSTYLE": TranslateEn = "DimStyle:"
        Case "INSERT_XY": TranslateEn = "Insert X / Y:"
        Case "PICK": TranslateEn = "Pick"
        Case "OPT_DIM": TranslateEn = "Draw Dimensions"
        Case "OPT_REBAR": TranslateEn = "Draw Reinforcement"
        Case "OPT_LAYERS": TranslateEn = "Create CSA Layers"
        Case "OPT_EXCEL": TranslateEn = "Open Excel"
        Case "BTN_EXCEL": TranslateEn = "Load Excel"
        Case "BTN_PREVIEW": TranslateEn = "Preview"
        Case "BTN_SECTION": TranslateEn = "Draw Section"
        Case "BTN_PLAN": TranslateEn = "Draw Plan"
        Case "BTN_CLEAR": TranslateEn = "Clear"
        Case "BTN_CANCEL": TranslateEn = "Cancel"
        Case "PV_SEC": TranslateEn = "SECTION"
        Case "PV_PLAN": TranslateEn = "PLAN VIEW"
        Case "PV_RISERS": TranslateEn = "RISERS"
        Case "PV_RISE": TranslateEn = "RISE"
        Case "PV_TREAD": TranslateEn = "TREAD"
        Case "PV_WIDTH": TranslateEn = "WIDTH"
        Case "DIR_UP": TranslateEn = "UP"
        Case "DIR_DN": TranslateEn = "DN"
        Case "READY": TranslateEn = "Ready"
        Case "FLOOR_H": TranslateEn = "Floor height"
        Case "ERR_NUM": TranslateEn = "Enter valid numeric stair parameters."
        Case "MSG_PREVIEW_OK": TranslateEn = "Preview updated in form and on CSA-PREVIEW"
        Case "MSG_SEC_OK": TranslateEn = "Section drawn on "
        Case "MSG_PLAN_OK": TranslateEn = "Plan drawn on "
        Case "MSG_CLEAR_OK": TranslateEn = "CSA-PREVIEW cleared"
        Case "MSG_EXCEL_OK": TranslateEn = "Loaded Excel: "
        Case "PICK_PROMPT": TranslateEn = "Pick stair insertion point: "
        Case Else: TranslateEn = key
    End Select
End Function

Private Function TranslateVi(ByVal key As String) As String
    Select Case key
        Case "EN_NAME": TranslateVi = "English"
        Case "VI_NAME": TranslateVi = "Ti" & ChrW$(&H1EBF) & "ng Vi" & ChrW$(&H1EC7) & "t"
        Case "TITLE": TranslateVi = "V" & ChrW$(&H1EBD) & " C" & ChrW$(&H1EA7) & "u Thang"
        Case "SUBTITLE": TranslateVi = "CSA TOOLS  |  V" & ChrW$(&H1EBC) & " C" & ChrW$(&H1EA6) & "U THANG"
        Case "HDR_PARAMS": TranslateVi = "  Th" & ChrW$(&H00F4) & "ng s" & ChrW$(&H1ED1) & " c" & ChrW$(&H1EA7) & "u thang"
        Case "HDR_PREVIEW": TranslateVi = "  Xem tr" & ChrW$(&H01B0) & ChrW$(&H1EDB) & "c"
        Case "HDR_OPTIONS": TranslateVi = "  T" & ChrW$(&H00F9) & "y ch" & ChrW$(&H1ECD) & "n"
        Case "TAB_GENERAL": TranslateVi = "C" & ChrW$(&H01A1) & " b" & ChrW$(&H1EA3) & "n"
        Case "TAB_PLAN_CAD": TranslateVi = "M" & ChrW$(&H1EB7) & "t b" & ChrW$(&H1EB1) & "ng & CAD"
        Case "TAB_SECTION": TranslateVi = "M" & ChrW$(&H1EB7) & "t c" & ChrW$(&H1EAF) & "t"
        Case "TAB_PLAN": TranslateVi = "M" & ChrW$(&H1EB7) & "t b" & ChrW$(&H1EB1) & "ng"
        Case "STAIR_NAME": TranslateVi = "T" & ChrW$(&H00EA) & "n thang:"
        Case "STAIR_TYPE": TranslateVi = "Lo" & ChrW$(&H1EA1) & "i thang:"
        Case "TYPE_2F": TranslateVi = "2 v" & ChrW$(&H1EBF) & " (c" & ChrW$(&H00F3) & " chi" & ChrW$(&H1EBF) & "u ngh" & ChrW$(&H1EC9) & ")"
        Case "TYPE_3F": TranslateVi = "3 v" & ChrW$(&H1EBF) & " (2 chi" & ChrW$(&H1EBF) & "u ngh" & ChrW$(&H1EC9) & ")"
        Case "TYPE_1F": TranslateVi = "1 v" & ChrW$(&H1EBF) & " th" & ChrW$(&H1EB3) & "ng"
        Case "WIDTH": TranslateVi = "R" & ChrW$(&H1ED9) & "ng v" & ChrW$(&H1EBF) & " (mm):"
        Case "BOT_ELEV": TranslateVi = "Cao " & ChrW$(&H0111) & ChrW$(&H1ED9) & " " & ChrW$(&H0111) & ChrW$(&H00E1) & "y:"
        Case "TOP_ELEV": TranslateVi = "Cao " & ChrW$(&H0111) & ChrW$(&H1ED9) & " " & ChrW$(&H0111) & ChrW$(&H1EC9) & "nh:"
        Case "RISER": TranslateVi = "Cao b" & ChrW$(&H1EAD) & "c (mm):"
        Case "TREAD": TranslateVi = "R" & ChrW$(&H1ED9) & "ng b" & ChrW$(&H1EAD) & "c (mm):"
        Case "SLAB": TranslateVi = "D" & ChrW$(&H00E0) & "y b" & ChrW$(&H1EA3) & "n (mm):"
        Case "SCALE": TranslateVi = "T" & ChrW$(&H1EF7) & " l" & ChrW$(&H1EC7) & ":"
        Case "FLIGHT1": TranslateVi = "S" & ChrW$(&H1ED1) & " b" & ChrW$(&H1EAD) & "c v" & ChrW$(&H1EBF) & " 1:"
        Case "FLIGHT2": TranslateVi = "S" & ChrW$(&H1ED1) & " b" & ChrW$(&H1EAD) & "c v" & ChrW$(&H1EBF) & " 2:"
        Case "FLIGHT3": TranslateVi = "S" & ChrW$(&H1ED1) & " b" & ChrW$(&H1EAD) & "c v" & ChrW$(&H1EBF) & " 3:"
        Case "MID_LAND": TranslateVi = "Chi" & ChrW$(&H1EBF) & "u ngh" & ChrW$(&H1EC9) & " (mm):"
        Case "UP_LAND": TranslateVi = "Chi" & ChrW$(&H1EBF) & "u t" & ChrW$(&H1EDB) & "i (mm):"
        Case "WELL_GAP": TranslateVi = "Khe thang (mm):"
        Case "SUP_WIDTH": TranslateVi = "R" & ChrW$(&H1ED9) & "ng g" & ChrW$(&H1ED1) & "i (mm):"
        Case "DIR": TranslateVi = "H" & ChrW$(&H01B0) & ChrW$(&H1EDB) & "ng l" & ChrW$(&H00EA) & "n:"
        Case "SEC_MARK": TranslateVi = "K" & ChrW$(&H00FD) & " hi" & ChrW$(&H1EC7) & "u MC:"
        Case "DIMSTYLE": TranslateVi = "DimStyle:"
        Case "INSERT_XY": TranslateVi = ChrW$(&H0110) & "i" & ChrW$(&H1EC3) & "m ch" & ChrW$(&H00E8) & "n X/Y:"
        Case "PICK": TranslateVi = "Ch" & ChrW$(&H1ECD) & "n"
        Case "OPT_DIM": TranslateVi = "V" & ChrW$(&H1EBD) & " k" & ChrW$(&H00ED) & "ch th" & ChrW$(&H01B0) & ChrW$(&H1EDB) & "c"
        Case "OPT_REBAR": TranslateVi = "V" & ChrW$(&H1EBD) & " c" & ChrW$(&H1ED1) & "t th" & ChrW$(&H00E9) & "p"
        Case "OPT_LAYERS": TranslateVi = "T" & ChrW$(&H1EA1) & "o layer CSA"
        Case "OPT_EXCEL": TranslateVi = "M" & ChrW$(&H1EDF) & " Excel"
        Case "BTN_EXCEL": TranslateVi = "T" & ChrW$(&H1EA3) & "i Excel"
        Case "BTN_PREVIEW": TranslateVi = "Xem tr" & ChrW$(&H01B0) & ChrW$(&H1EDB) & "c"
        Case "BTN_SECTION": TranslateVi = "V" & ChrW$(&H1EBD) & " m" & ChrW$(&H1EB7) & "t c" & ChrW$(&H1EAF) & "t"
        Case "BTN_PLAN": TranslateVi = "V" & ChrW$(&H1EBD) & " m" & ChrW$(&H1EB7) & "t b" & ChrW$(&H1EB1) & "ng"
        Case "BTN_CLEAR": TranslateVi = "X" & ChrW$(&H00F3) & "a nh" & ChrW$(&H00E1) & "p"
        Case "BTN_CANCEL": TranslateVi = ChrW$(&H0110) & ChrW$(&H00F3) & "ng"
        Case "PV_SEC": TranslateVi = "M" & ChrW$(&H1EB6) & "T C" & ChrW$(&H1EAE) & "T"
        Case "PV_PLAN": TranslateVi = "M" & ChrW$(&H1EB6) & "T B" & ChrW$(&H1EB0) & "NG"
        Case "PV_RISERS": TranslateVi = "B" & ChrW$(&H1EAC) & "C"
        Case "PV_RISE": TranslateVi = "CAO B" & ChrW$(&H1EAC) & "C"
        Case "PV_TREAD": TranslateVi = "R" & ChrW$(&H1ED8) & "NG B" & ChrW$(&H1EAC) & "C"
        Case "PV_WIDTH": TranslateVi = "R" & ChrW$(&H1ED8) & "NG"
        Case "DIR_UP": TranslateVi = "L" & ChrW$(&H00CA) & "N"
        Case "DIR_DN": TranslateVi = "XU" & ChrW$(&H1ED0) & "NG"
        Case "READY": TranslateVi = "S" & ChrW$(&H1EB5) & "n s" & ChrW$(&H00E0) & "ng"
        Case "FLOOR_H": TranslateVi = "Chi" & ChrW$(&H1EC1) & "u cao t" & ChrW$(&H1EA7) & "ng"
        Case "ERR_NUM": TranslateVi = "Vui l" & ChrW$(&H00F2) & "ng nh" & ChrW$(&H1EAD) & "p gi" & ChrW$(&H00E1) & " tr" & ChrW$(&H1ECB) & " s" & ChrW$(&H1ED1) & " h" & ChrW$(&H1EE3) & "p l" & ChrW$(&H1EC7) & "."
        Case "MSG_PREVIEW_OK": TranslateVi = ChrW$(&H0110) & ChrW$(&H00E3) & " c" & ChrW$(&H1EAD) & "p nh" & ChrW$(&H1EAD) & "t xem tr" & ChrW$(&H01B0) & ChrW$(&H1EDB) & "c tr" & ChrW$(&H00EA) & "n form v" & ChrW$(&H00E0) & " layer CSA-PREVIEW"
        Case "MSG_SEC_OK": TranslateVi = ChrW$(&H0110) & ChrW$(&H00E3) & " v" & ChrW$(&H1EBD) & " m" & ChrW$(&H1EB7) & "t c" & ChrW$(&H1EAF) & "t tr" & ChrW$(&H00EA) & "n layer "
        Case "MSG_PLAN_OK": TranslateVi = ChrW$(&H0110) & ChrW$(&H00E3) & " v" & ChrW$(&H1EBD) & " m" & ChrW$(&H1EB7) & "t b" & ChrW$(&H1EB1) & "ng tr" & ChrW$(&H00EA) & "n layer "
        Case "MSG_CLEAR_OK": TranslateVi = ChrW$(&H0110) & ChrW$(&H00E3) & " x" & ChrW$(&H00F3) & "a c" & ChrW$(&H00E1) & "c n" & ChrW$(&H00E9) & "t xem tr" & ChrW$(&H01B0) & ChrW$(&H1EDB) & "c tr" & ChrW$(&H00EA) & "n CSA-PREVIEW"
        Case "MSG_EXCEL_OK": TranslateVi = ChrW$(&H0110) & ChrW$(&H00E3) & " n" & ChrW$(&H1EA1) & "p Excel: "
        Case "PICK_PROMPT": TranslateVi = "Ch" & ChrW$(&H1ECD) & "n " & ChrW$(&H0111) & "i" & ChrW$(&H1EC3) & "m ch" & ChrW$(&H00E8) & "n c" & ChrW$(&H1EA7) & "u thang: "
        Case Else: TranslateVi = TranslateEn(key)
    End Select
End Function
