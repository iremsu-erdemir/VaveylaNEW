using Microsoft.AspNetCore.Diagnostics;
using Vaveyla.Api.Exceptions;

namespace Vaveyla.Api.Diagnostics;

public sealed class ForbiddenOperationExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not ForbiddenOperationException fex)
        {
            return false;
        }

        httpContext.Response.StatusCode = StatusCodes.Status403Forbidden;
        await httpContext.Response.WriteAsJsonAsync(
            new { message = fex.Message },
            cancellationToken);
        return true;
    }
}
