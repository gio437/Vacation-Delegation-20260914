page 50153 "Vacation Delegation Log"
{
    Caption = 'Vacation Delegation Log';
    PageType = List;
    SourceTable = "Vacation Delegation Log";
    UsageCategory = History;
    ApplicationArea = All;
    SourceTableView = sorting("Entry No.") order(descending);
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Logged At"; Rec."Logged At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the event happened.';
                }
                field("Event Type"; Rec."Event Type")
                {
                    ApplicationArea = All;
                    StyleExpr = EventStyleExpr;
                    ToolTip = 'Specifies what happened: a delegation was created, changed or removed, an approval was redirected, or the approved-user list was changed.';
                }
                field("Logged By"; Rec."Logged By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user whose action produced this entry. For a redirected approval this is the user who submitted the document, not the approver.';
                }
                field("Original Approver ID"; Rec."Original Approver ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the approver the workflow originally selected.';
                }
                field("Substitute User ID"; Rec."Substitute User ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the approver the request was routed to instead.';
                }
                field("Source Table Name"; Rec."Source Table Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the kind of record being approved, for example Purchase Header or Gen. Journal Line.';
                }
                field("Document Type"; Rec."Document Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document type being approved.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document number being approved.';
                }
                field("Approval Amount (LCY)"; Rec."Approval Amount (LCY)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the request that was redirected, in local currency.';
                }
                field("Sender ID"; Rec."Sender ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who submitted the document for approval.';
                }
                field("Hops Followed"; Rec."Hops Followed")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many delegations were chained to reach the final approver. Anything above 1 means the named substitute was also on leave.';
                }
                field("Delegation Entry No."; Rec."Delegation Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the delegation entry that authorised this redirection.';
                }
                field("Start Date"; Rec."Start Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the first date the authorising delegation covers.';
                }
                field("End Date"; Rec."End Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the last date the authorising delegation covers.';
                }
                field("Details"; Rec."Details")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the comment recorded on the delegation, which is the stated reason for the substitution.';
                }
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Specifies the unique log entry number.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        if Rec."Event Type" = Rec."Event Type"::"Approval Redirected" then
            EventStyleExpr := 'Attention'
        else
            EventStyleExpr := 'Standard';
    end;

    var
        EventStyleExpr: Text;
}
