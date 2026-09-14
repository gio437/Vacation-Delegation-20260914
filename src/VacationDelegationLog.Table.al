table 50152 "Vacation Delegation Log"
{
    Caption = 'Vacation Delegation Log';
    DataClassification = CustomerContent;
    LookupPageId = "Vacation Delegation Log";
    DrillDownPageId = "Vacation Delegation Log";

    // Append-only audit table. Nothing in this extension ever modifies or deletes a row,
    // and the permission set grants Read + Insert only. Note that a SUPER user can still
    // delete rows directly - BC has no true immutable storage - so for a hard evidentiary
    // trail this should be paired with BC's native Change Log on this table, or exported
    // to an external archive on a schedule.

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            DataClassification = SystemMetadata;
        }
        field(10; "Event Type"; Enum "Vacation Delegation Event")
        {
            Caption = 'Event';
        }
        field(20; "Logged At"; DateTime)
        {
            Caption = 'Date/Time';
        }
        field(30; "Logged By"; Code[50])
        {
            Caption = 'Performed By';
            TableRelation = User."User Name";
        }
        field(40; "Delegation Entry No."; Integer)
        {
            Caption = 'Delegation Entry No.';
            TableRelation = "Vacation Delegation Setup"."Entry No.";
        }
        field(50; "Original Approver ID"; Code[50])
        {
            Caption = 'Original Approver';
        }
        field(60; "Substitute User ID"; Code[50])
        {
            Caption = 'Redirected To';
        }
        field(70; "Start Date"; Date)
        {
            Caption = 'Delegation Start Date';
        }
        field(80; "End Date"; Date)
        {
            Caption = 'Delegation End Date';
        }
        field(90; "Hops Followed"; Integer)
        {
            Caption = 'Delegation Hops';
            ToolTip = 'Specifies how many delegations were chained to reach the final approver. 1 means a direct substitution.';
        }
        field(100; "Source Table ID"; Integer)
        {
            Caption = 'Source Table ID';
        }
        field(110; "Source Table Name"; Text[80])
        {
            Caption = 'Approval For';
        }
        field(120; "Document Type"; Text[30])
        {
            Caption = 'Document Type';
        }
        field(130; "Document No."; Code[20])
        {
            Caption = 'Document No.';
        }
        field(140; "Approval Amount"; Decimal)
        {
            Caption = 'Amount';
            AutoFormatType = 1;
        }
        field(150; "Approval Amount (LCY)"; Decimal)
        {
            Caption = 'Amount (LCY)';
            AutoFormatType = 1;
        }
        field(160; "Sender ID"; Code[50])
        {
            Caption = 'Requested By';
        }
        field(170; "Record ID"; RecordId)
        {
            Caption = 'Record';
        }
        field(180; "Details"; Text[250])
        {
            Caption = 'Details';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ByDate; "Logged At")
        {
        }
        key(ByApprover; "Original Approver ID", "Logged At")
        {
        }
        key(ByEvent; "Event Type", "Logged At")
        {
        }
    }

    /// <summary>
    /// Records that an approval was routed away from its intended approver. This is the
    /// entry that answers "who approved this instead of the person the workflow chose, and
    /// on what authority" - the delegation entry number and its date range are the "why".
    /// </summary>
    procedure LogApprovalRedirect(var ApprovalEntry: Record "Approval Entry"; OriginalApproverID: Code[50]; SubstituteUserID: Code[50]; DelegationEntryNo: Integer; HopsFollowed: Integer)
    var
        LogEntry: Record "Vacation Delegation Log";
        DelegationSetup: Record "Vacation Delegation Setup";
    begin
        LogEntry.Init();
        LogEntry."Event Type" := "Vacation Delegation Event"::"Approval Redirected";
        LogEntry."Logged At" := CurrentDateTime();
        LogEntry."Logged By" := CopyStr(UserId(), 1, MaxStrLen(LogEntry."Logged By"));
        LogEntry."Delegation Entry No." := DelegationEntryNo;
        LogEntry."Original Approver ID" := OriginalApproverID;
        LogEntry."Substitute User ID" := SubstituteUserID;
        LogEntry."Hops Followed" := HopsFollowed;

        if DelegationSetup.Get(DelegationEntryNo) then begin
            LogEntry."Start Date" := DelegationSetup."Start Date";
            LogEntry."End Date" := DelegationSetup."End Date";
            LogEntry."Details" := CopyStr(DelegationSetup."Comment", 1, MaxStrLen(LogEntry."Details"));
        end;

        LogEntry."Source Table ID" := ApprovalEntry."Table ID";
        LogEntry."Source Table Name" := GetTableCaption(ApprovalEntry."Table ID");
        LogEntry."Document Type" := CopyStr(Format(ApprovalEntry."Document Type"), 1, MaxStrLen(LogEntry."Document Type"));
        LogEntry."Document No." := ApprovalEntry."Document No.";
        LogEntry."Approval Amount" := ApprovalEntry.Amount;
        LogEntry."Approval Amount (LCY)" := ApprovalEntry."Amount (LCY)";
        LogEntry."Sender ID" := ApprovalEntry."Sender ID";
        LogEntry."Record ID" := ApprovalEntry."Record ID to Approve";
        LogEntry.Insert(true);
    end;

    /// <summary>
    /// Records creation, change, or removal of a delegation entry - i.e. someone activating
    /// or standing down a substitution.
    /// </summary>
    procedure LogDelegationChange(EventType: Enum "Vacation Delegation Event"; var DelegationSetup: Record "Vacation Delegation Setup")
    var
        LogEntry: Record "Vacation Delegation Log";
    begin
        LogEntry.Init();
        LogEntry."Event Type" := EventType;
        LogEntry."Logged At" := CurrentDateTime();
        LogEntry."Logged By" := CopyStr(UserId(), 1, MaxStrLen(LogEntry."Logged By"));
        LogEntry."Delegation Entry No." := DelegationSetup."Entry No.";
        LogEntry."Original Approver ID" := DelegationSetup."User ID";
        LogEntry."Substitute User ID" := DelegationSetup."Substitute User ID";
        LogEntry."Start Date" := DelegationSetup."Start Date";
        LogEntry."End Date" := DelegationSetup."End Date";
        LogEntry."Details" := CopyStr(DelegationSetup."Comment", 1, MaxStrLen(LogEntry."Details"));
        LogEntry.Insert(true);
    end;

    /// <summary>
    /// Records a change to the approved-user list itself, so that widening who may hold
    /// delegated approval authority is as traceable as using it.
    /// </summary>
    procedure LogApproverChange(EventType: Enum "Vacation Delegation Event"; var Approver: Record "Vacation Delegation Approver")
    var
        LogEntry: Record "Vacation Delegation Log";
    begin
        LogEntry.Init();
        LogEntry."Event Type" := EventType;
        LogEntry."Logged At" := CurrentDateTime();
        LogEntry."Logged By" := CopyStr(UserId(), 1, MaxStrLen(LogEntry."Logged By"));
        LogEntry."Original Approver ID" := Approver."User ID";
        if Approver.Blocked then
            LogEntry."Details" := CopyStr('Blocked. ' + Approver."Comment", 1, MaxStrLen(LogEntry."Details"))
        else
            LogEntry."Details" := CopyStr(Approver."Comment", 1, MaxStrLen(LogEntry."Details"));
        LogEntry.Insert(true);
    end;

    local procedure GetTableCaption(TableID: Integer): Text[80]
    var
        AllObjWithCaption: Record AllObjWithCaption;
    begin
        if TableID = 0 then
            exit('');
        if AllObjWithCaption.Get(AllObjWithCaption."Object Type"::Table, TableID) then
            exit(CopyStr(AllObjWithCaption."Object Caption", 1, 80));
        exit('');
    end;
}
