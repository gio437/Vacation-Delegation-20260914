permissionsetextension 50151 "Vacation Delegation Local Ext" extends LOCAL
{
    // Note the deliberate asymmetry: the log is Read + Insert only. No object in this
    // extension modifies or deletes a log row, and LOCAL does not grant the rights to do
    // so by hand. A SUPER user can still delete log rows directly - BC offers no truly
    // immutable table - so pair this with BC's native Change Log on table 50152 if the
    // trail needs to stand up to an external audit.
    Permissions =
        tabledata "Vacation Delegation Setup" = RIMD,
        tabledata "Vacation Delegation Approver" = RIMD,
        tabledata "Vacation Delegation Log" = RI,
        table "Vacation Delegation Setup" = X,
        table "Vacation Delegation Approver" = X,
        table "Vacation Delegation Log" = X,
        page "Vacation Delegation List" = X,
        page "Vacation Delegation Card" = X,
        page "Vacation Delegation Approvers" = X,
        page "Vacation Delegation Log" = X,
        codeunit "Vacation Delegation Mgmt" = X;
}
