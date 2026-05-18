namespace Vaveyla.Api.Models;

public enum PenaltyType : byte
{
    Warning = 1,
    MinorPenalty = 2,
    PointIncrease = 3,
    Suspension = 4,
    PermanentBan = 5,
}
