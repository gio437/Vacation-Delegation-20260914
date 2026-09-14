codeunit 50151 "Vacation Delegation Install"
{
    Subtype = Install;

    // Seeds the approved-user list on a fresh install. Without this, a new install would
    // start with an empty control list, which VerifyUserIsOnApprovedList treats as a
    // misconfiguration and blocks - correct, but unhelpful on day one.

    trigger OnInstallAppPerCompany()
    var
        Approver: Record "Vacation Delegation Approver";
    begin
        Approver.SeedDefaults();
    end;
}
