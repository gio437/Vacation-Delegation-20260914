table 50150 "Vacation Delegation Setup"
{
    Caption = 'Vacation Delegation Setup';
    DataClassification = CustomerContent;
    LookupPageId = "Vacation Delegation List";
    DrillDownPageId = "Vacation Delegation List";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            DataClassification = SystemMetadata;
        }
        field(10; "User ID"; Code[50])
        {
            Caption = 'Approver Going on Leave';
            TableRelation = "User Setup"."User ID";

            trigger OnValidate()
            begin
                VerifyApproverAndSubstituteDiffer();
                VerifyUserIsOnApprovedList("User ID");
            end;
        }
        field(20; "Substitute User ID"; Code[50])
        {
            Caption = 'Substitute Approver';
            TableRelation = "User Setup"."User ID";

            trigger OnValidate()
            begin
                VerifyApproverAndSubstituteDiffer();
                VerifyUserIsOnApprovedList("Substitute User ID");
            end;
        }
        field(30; "Start Date"; Date)
        {
            Caption = 'Start Date';

            trigger OnValidate()
            begin
                if ("End Date" <> 0D) and ("Start Date" > "End Date") then
                    Error('Start Date cannot be after End Date.');
            end;
        }
        field(40; "End Date"; Date)
        {
            Caption = 'End Date';

            trigger OnValidate()
            begin
                if ("Start Date" <> 0D) and ("End Date" < "Start Date") then
                    Error('End Date cannot be before Start Date.');
            end;
        }
        field(50; "Comment"; Text[100])
        {
            Caption = 'Comment';
        }
        field(60; "Currently Active"; Boolean)
        {
            Caption = 'Currently Active';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ByUser; "User ID", "Start Date", "End Date")
        {
        }
    }

    trigger OnInsert()
    var
        DelegationLog: Record "Vacation Delegation Log";
    begin
        ValidateRow();
        DelegationLog.LogDelegationChange("Vacation Delegation Event"::"Delegation Created", Rec);
    end;

    trigger OnModify()
    var
        DelegationLog: Record "Vacation Delegation Log";
    begin
        ValidateRow();
        DelegationLog.LogDelegationChange("Vacation Delegation Event"::"Delegation Modified", Rec);
    end;

    trigger OnDelete()
    var
        DelegationLog: Record "Vacation Delegation Log";
    begin
        VerifyCurrentUserIsApprover();
        DelegationLog.LogDelegationChange("Vacation Delegation Event"::"Delegation Deleted", Rec);
    end;

    /// <summary>
    /// Runs the checks that must hold for any saved row. Deliberately tolerant of blank
    /// fields: Business Central inserts a row on a list page as soon as the first field is
    /// filled in, so erroring on a not-yet-entered field would make in-grid entry impossible.
    /// Incomplete rows are simply never treated as active (see IsActiveOnDate /
    /// TryGetActiveSubstitute), so they cannot redirect any approvals.
    /// </summary>
    local procedure ValidateRow()
    begin
        VerifyCurrentUserIsApprover();
        VerifyApproverAndSubstituteDiffer();
        VerifyUserIsOnApprovedList("User ID");
        VerifyUserIsOnApprovedList("Substitute User ID");
        VerifyNoOverlappingDelegation();
        UpdateActiveFlag();
    end;

    local procedure VerifyCurrentUserIsApprover()
    var
        UserPermissions: Codeunit "User Permissions";
    begin
        if UserPermissions.IsSuper(UserSecurityId()) then
            exit;

        if "User ID" = '' then
            exit;

        if "User ID" <> UserId() then
            Error('You can only create, modify, or delete a vacation delegation for your own approvals.');
    end;

    local procedure VerifyApproverAndSubstituteDiffer()
    begin
        if ("User ID" <> '') and ("User ID" = "Substitute User ID") then
            Error('The substitute cannot be the same as the approver going on leave.');
    end;

    /// <summary>
    /// Prevents two delegations for the same approver from covering the same date, which
    /// would make the choice of substitute ambiguous.
    /// </summary>
    local procedure VerifyNoOverlappingDelegation()
    var
        ExistingDelegation: Record "Vacation Delegation Setup";
    begin
        if ("User ID" = '') or ("Start Date" = 0D) or ("End Date" = 0D) then
            exit;

        ExistingDelegation.SetRange("User ID", "User ID");
        ExistingDelegation.SetFilter("Entry No.", '<>%1', "Entry No.");
        ExistingDelegation.SetFilter("Start Date", '<=%1', "End Date");
        ExistingDelegation.SetFilter("End Date", '>=%1', "Start Date");
        if ExistingDelegation.FindFirst() then
            Error('This delegation overlaps an existing one for %1 (%2 to %3). Change the dates or edit the existing entry.',
                "User ID", ExistingDelegation."Start Date", ExistingDelegation."End Date");
    end;

    /// <summary>
    /// Restricts who can be entered in either the "User ID" (Approver Going on Leave) or
    /// "Substitute User ID" (Substitute Approver) fields to the approved-user list held in
    /// table "Vacation Delegation Approver", which admins maintain in Business Central. An
    /// empty list is treated as a misconfiguration and blocks all writes, so a control list
    /// that fails to populate can never silently degrade into "anyone may be a substitute".
    /// </summary>
    local procedure VerifyUserIsOnApprovedList(UserIDToCheck: Code[50])
    var
        Approver: Record "Vacation Delegation Approver";
    begin
        if UserIDToCheck = '' then
            exit;

        if Approver.ListIsEmpty() then
            Error('No approved delegation users are set up. An administrator must populate the Approved Delegation Users page before delegations can be created.');

        if not Approver.IsApproved(UserIDToCheck) then
            Error('%1 is not on the approved list of approvers/substitutes. Contact your administrator if this user should be added.', UserIDToCheck);
    end;

    local procedure UpdateActiveFlag()
    begin
        "Currently Active" := IsActiveToday();
    end;

    /// <summary>
    /// Returns true if today's date falls within this delegation's Start/End Date range
    /// (inclusive). Uses Today rather than WorkDate() deliberately - whether someone is
    /// physically on leave is a real-world calendar question, and a user's work date is
    /// often set to a prior period during close.
    /// </summary>
    procedure IsActiveToday(): Boolean
    begin
        exit(IsActiveOnDate(Today()));
    end;

    procedure IsActiveOnDate(ADate: Date): Boolean
    begin
        exit(("Start Date" <> 0D) and ("End Date" <> 0D) and ("Substitute User ID" <> '') and
             (ADate >= "Start Date") and (ADate <= "End Date"));
    end;

    /// <summary>
    /// Looks up whether OriginalApproverID has an active delegation on ADate, and if so returns
    /// the substitute. Returns true and sets SubstituteID if a delegation is active; returns
    /// false otherwise.
    ///
    /// If the substitute is themselves out on that date, the chain is followed (A out to B, B
    /// out to C, so approvals for A land on C). A hop limit and a cycle check stop A-to-B-to-A
    /// style loops; if a cycle is hit, the last resolvable substitute is returned.
    ///
    /// Rows with a blank substitute are ignored, so a half-entered row can never blank out an
    /// approval entry's Approver ID.
    /// </summary>
    procedure TryGetActiveSubstitute(OriginalApproverID: Code[50]; ADate: Date; var SubstituteID: Code[50]): Boolean
    var
        DelegationEntryNo: Integer;
        HopsFollowed: Integer;
    begin
        exit(TryGetActiveSubstituteWithDetails(OriginalApproverID, ADate, SubstituteID, DelegationEntryNo, HopsFollowed));
    end;

    /// <summary>
    /// As TryGetActiveSubstitute, but also reports which delegation authorised the
    /// substitution and how many hops were followed, so the caller can write a meaningful
    /// audit record. DelegationEntryNo is the FIRST delegation in the chain - the one
    /// belonging to the original approver - because that is the entry that authorised
    /// diverting the approval away from them.
    /// </summary>
    procedure TryGetActiveSubstituteWithDetails(OriginalApproverID: Code[50]; ADate: Date; var SubstituteID: Code[50]; var DelegationEntryNo: Integer; var HopsFollowed: Integer): Boolean
    var
        VisitedUsers: List of [Code[50]];
        CurrentUserID: Code[50];
        NextUserID: Code[50];
        StepEntryNo: Integer;
        KeepResolving: Boolean;
    begin
        DelegationEntryNo := 0;
        HopsFollowed := 0;

        if OriginalApproverID = '' then
            exit(false);

        CurrentUserID := OriginalApproverID;
        VisitedUsers.Add(CurrentUserID);

        KeepResolving := true;
        while KeepResolving and (HopsFollowed < MaxDelegationHops()) do
            if not FindDirectSubstitute(CurrentUserID, ADate, NextUserID, StepEntryNo) then
                KeepResolving := false
            else
                // Revisiting someone means a cycle (A to B to A). Stop and keep
                // whoever we last resolved to rather than looping forever.
                if VisitedUsers.Contains(NextUserID) then
                    KeepResolving := false
                else begin
                    if DelegationEntryNo = 0 then
                        DelegationEntryNo := StepEntryNo;
                    HopsFollowed += 1;
                    VisitedUsers.Add(NextUserID);
                    CurrentUserID := NextUserID;
                end;

        if CurrentUserID = OriginalApproverID then
            exit(false);

        SubstituteID := CurrentUserID;
        exit(true);
    end;

    /// <summary>
    /// Single-step lookup: the substitute directly named on the active delegation for
    /// ApproverID on ADate. Ordered by the primary key, so if overlapping rows somehow exist
    /// (they are blocked on write, but legacy data may predate that check) the most recently
    /// created entry - the highest Entry No. - wins.
    /// </summary>
    local procedure FindDirectSubstitute(ApproverID: Code[50]; ADate: Date; var SubstituteID: Code[50]; var DelegationEntryNo: Integer): Boolean
    var
        DelegationSetup: Record "Vacation Delegation Setup";
    begin
        DelegationSetup.SetRange("User ID", ApproverID);
        DelegationSetup.SetFilter("Substitute User ID", '<>%1', '');
        // Start Date must be set AND on/before ADate - a blank (0D) start would otherwise
        // satisfy '<=ADate' and make an unfinished row look active.
        DelegationSetup.SetFilter("Start Date", '>%1&<=%2', 0D, ADate);
        DelegationSetup.SetFilter("End Date", '>=%1', ADate);
        if DelegationSetup.FindLast() then begin
            SubstituteID := DelegationSetup."Substitute User ID";
            DelegationEntryNo := DelegationSetup."Entry No.";
            exit(true);
        end;
        exit(false);
    end;

    local procedure MaxDelegationHops(): Integer
    begin
        exit(10);
    end;
}
