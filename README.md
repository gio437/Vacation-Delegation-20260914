# Vacation Delegation for Dynamics 365 Business Central

An AL extension that automatically reroutes approval requests when an approver is on leave, with a full audit trail of every redirection.

Business Central has no native mechanism for temporary approval delegation. When an approver goes on vacation, approval entries route to them anyway and sit untouched until they return, or someone reassigns each one by hand.

This extension lets a user register a substitute for a date range. Approval entries created for that user during the range are automatically redirected to the substitute before they are written, and every redirection is logged.

## Features

- **Automatic redirection** via subscription to the standard `OnBeforeApprovalEntryInsert` event, so approvals are created correctly the first time rather than caught and fixed afterward
- **Delegation chains** with cycle detection, if A delegates to B and B is also out and delegated to C, approvals for A resolve to C
- **Controlled approver list**, only explicitly approved users may be named as an approver or substitute, and an empty list blocks rather than allows
- **Append-only audit log** capturing the original approver, substitute, hops followed, authorising delegation, document details, amount, requester, and RecordId
- **Self-service with guardrails**, users manage delegations for their own approvals, SUPER required to change who may hold delegated authority at all
- **Overlap prevention**, two delegations for the same approver covering the same date are rejected on write

## Requirements

- Business Central 24.0 or above
- Runtime 13.0
- Object ID range 50150 to 50199

## Installation

1. Clone or download this repository
2. Open the folder in VS Code with the AL Language extension installed
3. Update `app.json` with your own publisher name and a fresh GUID for `id`
4. Update the `DefaultUsers` list in `VacationDelegationApprover.Table.al` with user IDs valid in your environment, or leave it empty and use `PopulateFromApprovalSetup()` instead
5. Download symbols and publish

## Setup

1. Open **Approved Delegation Users** and populate the control list. A SUPER user is required.
   - Alternatively run `PopulateFromApprovalSetup()` to derive the list from your existing User Setup approval limits and Workflow User Group membership
2. Assign the `LOCAL` permission set, extended by this app, to users who need access
3. Users open **Vacation Delegations** and create an entry with a substitute and a date range

## Objects

| Object | ID |
|---|---|
| Vacation Delegation Setup (Table) | 50150 |
| Vacation Delegation Approver (Table) | 50151 |
| Vacation Delegation Log (Table) | 50152 |
| Vacation Delegation Mgmt (Codeunit) | 50150 |
| Vacation Delegation Install (Codeunit) | 50151 |
| Vacation Delegation Upgrade (Codeunit) | 50152 |
| Vacation Delegation Cleanup (Codeunit) | 50153 |
| Vacation Delegation Event (Enum) | 50150 |
| Vacation Delegation Local Ext (PermissionSetExt) | 50151 |

## Notes on the audit log

The permission set grants Read and Insert on the log table only, and no object in this extension modifies or deletes a log row.

A SUPER user can still delete rows directly. Business Central offers no truly immutable table storage. If the trail needs to stand up to an external audit, pair this with Business Central's native Change Log on table 50152, or export to an external archive on a schedule.

## Known limitations

- The `Currently Active` flag is recalculated on write rather than continuously, so it can display stale after an end date passes. Redirect behaviour is unaffected, since active-date logic is evaluated live.
- `ReassignOpenApprovalEntries()` handles entries created before a delegation was set up, or by batch jobs that do not fire the standard event. It is not currently surfaced on a page or scheduled.
- SUPER detection does not recognise SUPER granted through an Entra security group, only a directly assigned permission set.

## License

MIT
