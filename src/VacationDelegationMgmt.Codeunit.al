codeunit 50150 "Vacation Delegation Mgmt"
{
    // This codeunit subscribes to the standard Approval Entry creation event and,
    // if the assigned approver has an active Vacation Delegation Setup entry for
    // today's date, swaps the Approver ID to the substitute before the
    // entry is inserted. Every swap is written to the Vacation Delegation Log.

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Approvals Mgmt.", 'OnBeforeApprovalEntryInsert', '', false, false)]
    local procedure OnBeforeApprovalEntryInsert_SwapForVacationDelegation(var ApprovalEntry: Record "Approval Entry"; ApprovalEntryArgument: Record "Approval Entry"; WorkflowStepArgument: Record "Workflow Step Argument"; ApproverId: Code[50]; var IsHandled: Boolean)
    var
        DelegationSetup: Record "Vacation Delegation Setup";
        DelegationLog: Record "Vacation Delegation Log";
        OriginalApproverID: Code[50];
        SubstituteID: Code[50];
        DelegationEntryNo: Integer;
        HopsFollowed: Integer;
    begin
        if ApprovalEntry."Approver ID" = '' then
            exit;

        OriginalApproverID := ApprovalEntry."Approver ID";

        // Today, not WorkDate() - being on leave is a real-world calendar fact, and a user's
        // work date is often set to a prior period during month-end close.
        if not DelegationSetup.TryGetActiveSubstituteWithDetails(OriginalApproverID, Today(), SubstituteID, DelegationEntryNo, HopsFollowed) then
            exit;

        if SubstituteID = '' then
            exit;

        ApprovalEntry."Approver ID" := SubstituteID;

        // Logged in the same transaction as the approval entry itself, so the log can never
        // claim a redirection that was subsequently rolled back, and never miss one that
        // committed.
        DelegationLog.LogApprovalRedirect(ApprovalEntry, OriginalApproverID, SubstituteID, DelegationEntryNo, HopsFollowed);
    end;

    /// <summary>
    /// Optional helper for manually re-routing already-open approval entries
    /// (for example, entries created before the delegation was set up, or entries
    /// created by a batch job that does not fire the standard event).
    /// Call this from a scheduled job or a manual action page if needed.
    /// </summary>
    procedure ReassignOpenApprovalEntries()
    var
        ApprovalEntry: Record "Approval Entry";
        DelegationSetup: Record "Vacation Delegation Setup";
        DelegationLog: Record "Vacation Delegation Log";
        OriginalApproverID: Code[50];
        SubstituteID: Code[50];
        DelegationEntryNo: Integer;
        HopsFollowed: Integer;
    begin
        ApprovalEntry.SetRange(Status, ApprovalEntry.Status::Open);
        if ApprovalEntry.FindSet(true) then
            repeat
                OriginalApproverID := ApprovalEntry."Approver ID";
                if DelegationSetup.TryGetActiveSubstituteWithDetails(OriginalApproverID, Today(), SubstituteID, DelegationEntryNo, HopsFollowed) then
                    if (SubstituteID <> '') and (OriginalApproverID <> SubstituteID) then begin
                        ApprovalEntry."Approver ID" := SubstituteID;
                        ApprovalEntry.Modify(true);
                        DelegationLog.LogApprovalRedirect(ApprovalEntry, OriginalApproverID, SubstituteID, DelegationEntryNo, HopsFollowed);
                    end;
            until ApprovalEntry.Next() = 0;
    end;
}
