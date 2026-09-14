codeunit 50152 "Vacation Delegation Upgrade"
{
    Subtype = Upgrade;

    // Upgrading from 1.x fires this, not the install trigger. Without it, an existing
    // tenant would land on 2.x with an empty approved-user list and every delegation
    // write would be blocked until an admin populated the page by hand.

    trigger OnUpgradePerCompany()
    var
        Approver: Record "Vacation Delegation Approver";
    begin
        Approver.SeedDefaults();
    end;
}
