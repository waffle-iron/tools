Option Explicit

' VBScript.RegExp オブジェクトを生成するヘルパー
Function RegExp(Pattern As String)
    Dim re As Object
    Set re = CreateObject("VBScript.RegExp")
    re.Pattern = Pattern
    Set RegExp = re
End Function

' sysdate -n の形式の数式をPostgreSQLで処理できる式に変換する
Function SysdateExpressionToPg(OrgExp As String)
    Dim Exp As String
    Exp = OrgExp
    Do
        ' 数式全体から sysdate を使った部分式を抜き出す。
        Dim Matched As Object
        Set Matched = RegExp("sysdate\s*-\s*\d+").Execute(Exp)
        If Matched.Count = 0 Then
            ' 処理できる sysdate 式がなくなったら終了
            SysdateExpressionToPg = Exp
            Exit Function
        End If
        Dim SysdateExpPart As String
        SysdateExpPart = Matched(0).Value
        
        ' sysdateを使った部分式から、日数部分を抜き出す。
        Set Matched = RegExp("\d+").Execute(SysdateExpPart)
        Dim Days As String
        Days = Matched(0).Value
        
        ' PostgreSQL用の新しい数式を組み立てる。
        Dim PgExpPart As String
        PgExpPart = "current_timestamp - interval '" & Days & " day'"
        
        ' sysdateを使った部分式を、新しい数式に置き換える。
        Exp = RegExp("sysdate\s*-\s*" & Days).Replace(Exp, PgExpPart)
    Loop
End Function

' sysdate - n 式および、単体のsysdateをcurrent_timestampを使った表記に置き換える。
Function SysdateToPg(Expression As String)
    Dim NewExp As String
    NewExp = SysdateExpressionToPg(Expression)
    SysdateToPg = RegExp("sysdate").Replace(NewExp, "current_timestamp")
End Function

' 選択されているワークシート中の全セルのsysdate式を変換する。
Sub ConvertAllSysdate()
    Dim Sheet As Worksheet
    Set Sheet = ActiveSheet ' 仮にグラフシートなどがActiveだとここでエラー
    
    Dim Found As Range
    Set Found = Sheet.Cells.Find(What:="sysdate", After:=ActiveCell, LookIn:=xlFormulas, _
        LookAt:=xlPart, SearchOrder:=xlByRows, SearchDirection:=xlNext, _
        MatchCase:=False, MatchByte:=False, SearchFormat:=False)
    If Not Nothing Is Found Then
        Dim FirstAddress As String
        FirstAddress = Found.Address
        Dim Count As Long
        Count = 0
        Do
            Count = Count + 1
            Dim Old As String
            Old = Found.Formula
            Found.Formula = SysdateToPg(Old)
            Debug.Print Found.Address & " : " & Old & " -> " & Found.Formula
            Set Found = Sheet.Cells.FindNext(Found)
            Set Found = Sheet.Cells.FindNext(Found)
            If Nothing Is Found Then
                Exit Do
            End If
        Loop While Found.Address <> FirstAddress
        MsgBox Count & " cells done."
   End If
End Sub

