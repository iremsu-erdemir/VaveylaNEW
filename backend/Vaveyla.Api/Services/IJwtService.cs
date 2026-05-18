using Vaveyla.Api.Models;

namespace Vaveyla.Api.Services;

public interface IJwtService
{
    string GenerateToken(User user);
}
