page 50151 "Vacation Delegation Card"
{
    Caption = 'Vacation Delegation Entry';
    PageType = Card;
    SourceTable = "Vacation Delegation Setup";
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                    Caption = 'Approver Going on Leave';
                    ToolTip = 'The user whose approvals should be redirected while they are out.';
                }
                field("Substitute User ID"; Rec."Substitute User ID")
                {
                    ApplicationArea = All;
                    Caption = 'Substitute Approver';
                    ToolTip = 'The user who will receive the approvals instead, during the date range below.';
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
                field("Comment"; Rec."Comment")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a free-text comment for this delegation entry.';
                }
            }
        }
    }
}
