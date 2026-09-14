page 50152 "Vacation Delegation Approvers"
{
    Caption = 'Approved Delegation Users';
    PageType = List;
    SourceTable = "Vacation Delegation Approver";
    UsageCategory = Administration;
    ApplicationArea = All;
    Editable = true;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a user who may be named as an approver going on leave, or as a substitute approver.';
                }
                field("Full Name"; Rec."Full Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the full name recorded against this user, to confirm you have the right person.';
                }
                field(Blocked; Rec.Blocked)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies that this user can no longer be used in new delegations, without removing the record that they were once approved.';
                }
                field("Comment"; Rec."Comment")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies why this user is on the approved list.';
                }
                field("Added By"; Rec."Added By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who added this user to the approved list.';
                }
                field("Added On"; Rec."Added On")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when this user was added to the approved list.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(PopulateFromApprovalSetup)
            {
                ApplicationArea = All;
                Caption = 'Populate from Approval Setup';
                Image = SuggestField;
                ToolTip = 'Adds every user Business Central already treats as an approver: anyone named as an Approver ID in User Setup, anyone holding an approval limit, and any member of a workflow user group. Only adds - never removes anyone you have deliberately excluded.';

                trigger OnAction()
                var
                    Approver: Record "Vacation Delegation Approver";
                    AddedCount: Integer;
                begin
                    AddedCount := Approver.PopulateFromApprovalSetup();
                    if AddedCount = 0 then
                        Message('No new users found. Everyone Business Central treats as an approver is already on this list.')
                    else
                        Message('%1 user(s) added from Business Central''s approval setup. Review the list and block anyone who should not hold delegated approval authority.', AddedCount);
                    CurrPage.Update(false);
                end;
            }
            action(ShowLog)
            {
                ApplicationArea = All;
                Caption = 'Delegation Log';
                Image = Log;
                RunObject = page "Vacation Delegation Log";
                ToolTip = 'Opens the audit log of delegation changes and redirected approvals.';
            }
        }
    }
}
