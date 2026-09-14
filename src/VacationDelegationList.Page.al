page 50150 "Vacation Delegation List"
{
    Caption = 'Vacation Delegation';
    PageType = List;
    SourceTable = "Vacation Delegation Setup";
    UsageCategory = Administration;
    ApplicationArea = All;
    CardPageId = "Vacation Delegation Card";
    Editable = true;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Specifies the unique entry number of the delegation.';
                }
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                    Caption = 'Approver Going on Leave';
                    ToolTip = 'Specifies the user whose approvals should be redirected while they are out.';
                }
                field("Substitute User ID"; Rec."Substitute User ID")
                {
                    ApplicationArea = All;
                    Caption = 'Substitute Approver';
                    ToolTip = 'Specifies the user who will receive the approvals instead, during the date range.';
                }
                field("Start Date"; Rec."Start Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the first date on which approvals are redirected to the substitute.';
                }
                field("End Date"; Rec."End Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the last date on which approvals are redirected to the substitute.';
                }
                field("Currently Active"; Rec."Currently Active")
                {
                    ApplicationArea = All;
                    StyleExpr = ActiveStyleExpr;
                    ToolTip = 'Specifies whether this delegation is active today.';
                }
                field("Comment"; Rec."Comment")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a free-text comment for this delegation entry.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ShowLog)
            {
                ApplicationArea = All;
                Caption = 'Delegation Log';
                Image = Log;
                RunObject = page "Vacation Delegation Log";
                ToolTip = 'Opens the audit log of delegation changes and every approval that was redirected as a result.';
            }
            action(ShowApprovers)
            {
                ApplicationArea = All;
                Caption = 'Approved Delegation Users';
                Image = Users;
                RunObject = page "Vacation Delegation Approvers";
                ToolTip = 'Opens the list of users who may be named as an approver going on leave or as a substitute approver.';
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        Rec."Currently Active" := Rec.IsActiveToday();
        if Rec."Currently Active" then
            ActiveStyleExpr := 'Favorable'
        else
            ActiveStyleExpr := 'Standard';
    end;

    var
        ActiveStyleExpr: Text;
}
