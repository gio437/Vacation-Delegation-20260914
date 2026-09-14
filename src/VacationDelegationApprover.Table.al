table 50151 "Vacation Delegation Approver"
{
    Caption = 'Approved Delegation User';
    DataClassification = CustomerContent;
    LookupPageId = "Vacation Delegation Approvers";
    DrillDownPageId = "Vacation Delegation Approvers";

    fields
    {
        field(1; "User ID"; Code[50])
        {
            Caption = 'User ID';
            NotBlank = true;
            TableRelation = "User Setup"."User ID";
        }
        field(10; "Full Name"; Text[80])
        {
            Caption = 'Full Name';
            FieldClass = FlowField;
            CalcFormula = lookup(User."Full Name" where("User Name" = field("User ID")));
            Editable = false;
        }
        field(20; Blocked; Boolean)
        {
            Caption = 'Blocked';
            ToolTip = 'Prevents this user from being used in new delegations without removing the historical record that they were once approved.';
        }
        field(30; "Comment"; Text[100])
        {
            Caption = 'Comment';
        }
        field(40; "Added By"; Code[50])
        {
            Caption = 'Added By';
            Editable = false;
        }
        field(50; "Added On"; DateTime)
        {
            Caption = 'Added On';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "User ID")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "User ID", "Full Name", Blocked)
        {
        }
    }

    trigger OnInsert()
    var
        DelegationLog: Record "Vacation Delegation Log";
    begin
        VerifyCurrentUserIsSuper();
        "Added By" := CopyStr(UserId(), 1, MaxStrLen("Added By"));
        "Added On" := CurrentDateTime();
        DelegationLog.LogApproverChange("Vacation Delegation Event"::"Approver Added", Rec);
    end;

    trigger OnModify()
    var
        DelegationLog: Record "Vacation Delegation Log";
    begin
        VerifyCurrentUserIsSuper();
        DelegationLog.LogApproverChange("Vacation Delegation Event"::"Approver Modified", Rec);
    end;

    trigger OnDelete()
    var
        DelegationLog: Record "Vacation Delegation Log";
    begin
        VerifyCurrentUserIsSuper();
        DelegationLog.LogApproverChange("Vacation Delegation Event"::"Approver Removed", Rec);
    end;

    /// <summary>
    /// Unlike the delegation table itself (self-service for your own row, SUPER for
    /// anyone's), the approved-user list has no self-service case - every write requires
    /// SUPER. This is the list that decides who may hold delegated approval authority at
    /// all, so it is deliberately not opened up via the LOCAL permission set the rest of
    /// this extension rides on. SeedDefaults() bypasses this (see its own comment) because
    /// it runs during install/upgrade, not as an interactive user action.
    /// </summary>
    local procedure VerifyCurrentUserIsSuper()
    var
        UserPermissions: Codeunit "User Permissions";
    begin
        if UserPermissions.IsSuper(UserSecurityId()) then
            exit;
        Error('Only a user with the SUPER permission set can add, modify, or remove approved delegation users. Note: this does not detect SUPER granted through an Entra/Azure Security Group - only a directly assigned SUPER permission set.');
    end;

    /// <summary>
    /// True if UserIDToCheck is on the approved list and not blocked.
    /// </summary>
    procedure IsApproved(UserIDToCheck: Code[50]): Boolean
    var
        Approver: Record "Vacation Delegation Approver";
    begin
        if UserIDToCheck = '' then
            exit(false);
        if not Approver.Get(UserIDToCheck) then
            exit(false);
        exit(not Approver.Blocked);
    end;

    /// <summary>
    /// True if the approved-user list has no usable rows at all. Callers treat this as a
    /// misconfiguration and block writes rather than silently allowing everyone through -
    /// an empty control list must never mean "no control".
    /// </summary>
    procedure ListIsEmpty(): Boolean
    var
        Approver: Record "Vacation Delegation Approver";
    begin
        Approver.SetRange(Blocked, false);
        exit(Approver.IsEmpty());
    end;

    /// <summary>
    /// Seeds the list with the users who were hardcoded in version 1.x, so that upgrading
    /// from a hardcoded build does not leave the control list empty. Only runs when the
    /// table is completely empty, so it can never overwrite an admin's curated list.
    ///
    /// Called from the Install and Upgrade codeunits, which run as part of publishing the
    /// extension rather than as an interactive user action - there is no meaningful "current
    /// user" to hold to the SUPER requirement, and the shipped default list is itself the
    /// authorization. Inserts with RunTrigger=false to bypass VerifyCurrentUserIsSuper, and
    /// replicates OnInsert's other bookkeeping (Added By/On, logging) by hand instead.
    /// </summary>
    procedure SeedDefaults()
    var
        Approver: Record "Vacation Delegation Approver";
        DelegationLog: Record "Vacation Delegation Log";
        DefaultUsers: List of [Code[50]];
        DefaultUser: Code[50];
    begin
        if not Approver.IsEmpty() then
            exit;

        // Replace with the user IDs already approved in your environment, or leave this
        // list empty and use PopulateFromApprovalSetup() to derive it from BC's own
        // User Setup and Workflow User Group configuration instead.
        DefaultUsers.Add('APPROVER01');
        DefaultUsers.Add('APPROVER02');

        // Inserted without the User Setup existence check that AddUser applies. These users
        // were already explicitly approved under 1.x, so an upgrade must not silently drop
        // anyone whose User Setup record happens to be missing or renamed - better that the
        // admin sees them on the list and removes them deliberately.
        foreach DefaultUser in DefaultUsers do
            if not Approver.Get(DefaultUser) then begin
                Approver.Init();
                Approver."User ID" := DefaultUser;
                Approver."Comment" := 'Seeded from hardcoded 1.x list on upgrade';
                Approver."Added By" := CopyStr(UserId(), 1, MaxStrLen(Approver."Added By"));
                Approver."Added On" := CurrentDateTime();
                Approver.Insert(false);
                DelegationLog.LogApproverChange("Vacation Delegation Event"::"Approver Added", Approver);
            end;
    end;

    /// <summary>
    /// Adds every user Business Central already treats as an approver, drawn from BC's own
    /// setup rather than a maintained-by-hand list:
    ///   1. Anyone named as someone else's "Approver ID" in User Setup.
    ///   2. Anyone in User Setup carrying an approval limit or an unlimited-approval flag.
    ///   3. Any member of a Workflow User Group.
    /// Purely additive - it never removes or blocks anyone, so an admin's deliberate
    /// exclusions survive a re-run.
    /// </summary>
    procedure PopulateFromApprovalSetup(): Integer
    var
        UserSetup: Record "User Setup";
        WorkflowUserGroupMember: Record "Workflow User Group Member";
        AddedCount: Integer;
    begin
        if UserSetup.FindSet() then
            repeat
                if UserSetup."Approver ID" <> '' then
                    if AddUser(UserSetup."Approver ID", 'Named as an Approver ID in User Setup') then
                        AddedCount += 1;

                if UserSetupGrantsApprovalRights(UserSetup) then
                    if AddUser(UserSetup."User ID", 'Holds approval limits in User Setup') then
                        AddedCount += 1;
            until UserSetup.Next() = 0;

        if WorkflowUserGroupMember.FindSet() then
            repeat
                if AddUser(WorkflowUserGroupMember."User Name", 'Member of workflow user group ' + WorkflowUserGroupMember."Workflow User Group Code") then
                    AddedCount += 1;
            until WorkflowUserGroupMember.Next() = 0;

        exit(AddedCount);
    end;

    local procedure UserSetupGrantsApprovalRights(var UserSetup: Record "User Setup"): Boolean
    begin
        exit(UserSetup."Unlimited Sales Approval" or
             UserSetup."Unlimited Purchase Approval" or
             UserSetup."Unlimited Request Approval" or
             (UserSetup."Sales Amount Approval Limit" > 0) or
             (UserSetup."Purchase Amount Approval Limit" > 0) or
             (UserSetup."Request Amount Approval Limit" > 0));
    end;

    /// <summary>
    /// Inserts one approved user. Returns true only if a row was actually created, so
    /// callers can report an accurate count. Skips users with no User Setup record, since
    /// the "User ID" field's table relation would reject them anyway.
    /// </summary>
    procedure AddUser(UserIDToAdd: Code[50]; Reason: Text[100]): Boolean
    var
        Approver: Record "Vacation Delegation Approver";
        UserSetup: Record "User Setup";
    begin
        if UserIDToAdd = '' then
            exit(false);
        if Approver.Get(UserIDToAdd) then
            exit(false);
        if not UserSetup.Get(UserIDToAdd) then
            exit(false);

        Approver.Init();
        Approver."User ID" := UserIDToAdd;
        Approver."Comment" := Reason;
        Approver.Insert(true);
        exit(true);
    end;
}
