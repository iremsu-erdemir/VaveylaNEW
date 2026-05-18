namespace Vaveyla.Api.Models;

public enum AdminActionType : byte
{
    Warning = 1,
    AddPenaltyPoints = 2,
    SuspendUser = 3,
    PermanentBan = 4,
    RejectFeedback = 5,
}
