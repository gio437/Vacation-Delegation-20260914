codeunit 50153 "Vacation Delegation Cleanup"
{
    // One-time utility to remove leftover "VACATION DELEGATION" Access Control rows
    // from the earlier custom-permission-set approach, now replaced by the
    // permissionsetextension on LOCAL. Delete this codeunit after running it once.

    trigger OnRun()
    begin
        RemoveLegacyPermissionAssignments();
    end;

    local procedure RemoveLegacyPermissionAssignments()
    var
        AccessControl: Record "Access Control";
    begin
        AccessControl.SetRange("Role ID", 'VACATION DELEGATION');
        AccessControl.DeleteAll(true);
    end;
}
