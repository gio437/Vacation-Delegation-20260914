# Vacation Delegation for Business Central

**An AL extension that automatically reroutes approval requests when an approver is on leave, with a full audit trail of every redirection.**

Business Central has no native way to say "I am out from the 12th to the 20th, send my approvals to someone else." The approval engine looks up an approver and routes to them regardless of whether that person is at their desk. In practice this means approvals sit untouched until the approver returns, or an administrator manually reassigns them one at a time.

This extension closes that gap.

---

## The problem

In a multi-entity environment, approval workflows route purchase documents, journals, and requests to a named approver. When that person goes on vacation:

- Documents queue up and nothing tells anyone why
- Someone has to manually reassign each open entry, or the requester chases the wrong person
- A user with SUPER rights sometimes just approves it themselves, which defeats the point of having an approval workflow at all

None of those outcomes are good, and the third one is an internal controls problem, not just an inconvenience.

---

## How it works

The extension subscribes to the standard `OnBeforeApprovalEntryInsert` event on Codeunit 1535 (`Approvals Mgmt.`). Before Business Central writes an approval entry, the extension checks whether the assigned approver has an active delegation covering today's date. If so, it swaps the `Approver ID` to the substitute and writes an audit record in the same transaction.

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"Approvals Mgmt.", 'OnBeforeApprovalEntryInsert', '', false, false)]
local procedure OnBeforeApprovalEntryInsert_SwapForVacationDelegation(var ApprovalEntry: Record "Approval Entry"; ...)
begin
    if ApprovalEntry."Approver ID" = '' then
        exit;

    OriginalApproverID := ApprovalEntry."Approver ID";

    if not DelegationSetup.TryGetActiveSubstituteWithDetails(
        OriginalApproverID, Today(), SubstituteID, DelegationEntryNo, HopsFollowed) then
        exit;

    ApprovalEntry."Approver ID" := SubstituteID;

    DelegationLog.LogApprovalRedirect(
        ApprovalEntry, OriginalApproverID, SubstituteID, DelegationEntryNo, HopsFollowed);
end;
```

Because the subscriber runs before the insert, the approval is created correctly the first time. Nothing has to be caught and fixed afterward.

---

## Design decisions worth explaining

### Today() rather than WorkDate()

Business Central code conventionally uses `WorkDate()`. This extension deliberately does not.

During month-end close, finance users routinely set their work date back into the prior period to post adjusting entries. If delegation keyed off `WorkDate()`, an approver working on December's close in mid-January would have their January vacation delegation evaluated against a December date, and the redirect would silently not fire.

Whether someone is physically on leave is a real-world calendar fact. It is not a posting-period question.

### Delegation chains, with a cycle guard

If A delegates to B, and B is also out and has delegated to C, approvals for A should land on C, not on someone who is also away.

`TryGetActiveSubstituteWithDetails` walks the chain, tracking visited users in a `List of [Code[50]]`. If it encounters someone already visited (A to B to A), it stops and keeps the last resolvable substitute rather than looping. A hop limit of 10 provides a second backstop.

```al
while KeepResolving and (HopsFollowed < MaxDelegationHops()) do
    if not FindDirectSubstitute(CurrentUserID, ADate, NextUserID, StepEntryNo) then
        KeepResolving := false
    else
        if VisitedUsers.Contains(NextUserID) then
            KeepResolving := false
        else begin
            if DelegationEntryNo = 0 then
                DelegationEntryNo := StepEntryNo;
            HopsFollowed += 1;
            VisitedUsers.Add(NextUserID);
            CurrentUserID := NextUserID;
        end;
```

The logged `DelegationEntryNo` is deliberately the **first** delegation in the chain, the one belonging to the original approver, because that is the entry that authorised diverting the approval away from them in the first place.

### An empty control list blocks, it does not allow

Only users on an explicit approved list can be named as an approver or substitute. If that list is empty, the extension errors rather than allowing anyone through.

```al
if Approver.ListIsEmpty() then
    Error('No approved delegation users are set up. An administrator must populate ' +
          'the Approved Delegation Users page before delegations can be created.');
```

This matters because the failure mode of a control list that fails to load should never be "no control." A misconfiguration should stop work, not silently widen who can hold approval authority.

### Partial rows can never redirect anything

Business Central inserts a row on a list page as soon as the first field is filled in. Erroring on a not-yet-entered field would make in-grid entry impossible.

Rather than fighting that, validation is deliberately tolerant of blank fields on write, and `IsActiveOnDate` requires every field to be populated before a row counts as active:

```al
procedure IsActiveOnDate(ADate: Date): Boolean
begin
    exit(("Start Date" <> 0D) and ("End Date" <> 0D) and ("Substitute User ID" <> '') and
         (ADate >= "Start Date") and (ADate <= "End Date"));
end;
```

A half-entered row is simply never active, so it cannot blank out an approval entry's `Approver ID`.

Similarly, `FindDirectSubstitute` filters `Start Date` with `'>%1&<=%2'` against `0D` rather than just `<= ADate`, because a blank date would otherwise satisfy a simple less-than filter and make an unfinished row look active.

### Two different authority levels

The delegation table is self-service: you can create, modify, or delete a delegation for **your own** approvals, and SUPER can act for anyone.

The approved-user list has no self-service case at all. Every write requires SUPER, and it is deliberately not opened up through the `LOCAL` permission set extension the rest of the feature rides on. That list decides who may hold delegated approval authority, which is a different question from who may use it.

### The audit log is append-only, and says so honestly

The permission set grants `RI` (Read and Insert) on the log table, not `RIMD`. No object in the extension ever modifies or deletes a log row.

The code comment does not overclaim:

> A SUPER user can still delete rows directly, BC has no true immutable storage, so for a hard evidentiary trail this should be paired with BC's native Change Log on this table, or exported to an external archive on a schedule.

Every redirect logs the original approver, the substitute, how many hops were followed, which delegation authorised it, the document type and number, the amount, the requester, and the `RecordId`. The question an auditor actually asks is "who approved this instead of the person the workflow chose, and on what authority," and the log answers both halves.

Changes to the approved-user list are logged too, so widening who may hold delegated authority is as traceable as using it.

---

## Install and upgrade

Version 1.x carried a hardcoded approver list. Version 2.x moved it into a maintainable table.

That creates an upgrade hazard: an existing tenant moving to 2.x would land with an empty control list, and since an empty list blocks all writes, every delegation would break until an admin populated the page by hand.

Both an Install codeunit (`OnInstallAppPerCompany`) and an Upgrade codeunit (`OnUpgradePerCompany`) call `SeedDefaults()`, which only runs when the table is completely empty so it can never overwrite a curated list.

There is also `PopulateFromApprovalSetup()`, which derives the list from Business Central's own configuration rather than a hand-maintained one: anyone named as another user's `Approver ID`, anyone carrying an approval limit or unlimited-approval flag in User Setup, and any member of a Workflow User Group. It is purely additive, so an admin's deliberate exclusions survive a re-run.

---

## Object inventory

| Object | ID | Purpose |
|---|---|---|
| `Vacation Delegation Setup` (Table) | 50150 | Delegation records with date ranges and validation |
| `Vacation Delegation Approver` (Table) | 50151 | Control list of who may hold delegated authority |
| `Vacation Delegation Log` (Table) | 50152 | Append-only audit trail |
| `Vacation Delegation Mgmt` (Codeunit) | 50150 | Event subscriber and manual reassignment helper |
| `Vacation Delegation Install` (Codeunit) | 50151 | Seeds control list on fresh install |
| `Vacation Delegation Upgrade` (Codeunit) | 50152 | Seeds control list on 1.x to 2.x upgrade |
| `Vacation Delegation Event` (Enum) | 50150 | Seven audit event types, extensible |
| `Vacation Delegation Local Ext` (PermissionSetExt) | 50151 | Extends LOCAL, log is Read + Insert only |

Plus list, card, approvers, and log pages.

Runtime 13.0, targeting Business Central 24.0 and above. Deployed and running in production.

---

## What I would do differently

**Scheduled cleanup.** The `Currently Active` flag is calculated on write, not continuously. A delegation whose end date passes while nobody touches the record keeps a stale flag until the next modify. The active-date logic itself is evaluated live at redirect time so behaviour is correct either way, but the displayed flag can lag. A job queue entry recalculating it nightly would fix the display.

**Cross-company behaviour.** Both install and upgrade run per-company, which is correct, but in a 100-plus entity environment that is worth load-testing rather than assuming.

**The manual reassignment helper is unwired.** `ReassignOpenApprovalEntries()` exists for entries created before a delegation was set up, or by batch jobs that do not fire the standard event. It is not currently surfaced on a page or scheduled. That is a deliberate scope decision, not an oversight, but it is unfinished work.
