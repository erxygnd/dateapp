using Fildir.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Fildir.Api.Controllers;

[ApiController]
[Route("api/health")]
public sealed class HealthController(FildirDbContext dbContext) : ControllerBase
{
    [HttpGet]
    public IActionResult Get()
    {
        return Ok(new
        {
            status = "ok",
            service = "fildir-api",
            utc = DateTimeOffset.UtcNow
        });
    }

    [HttpGet("db")]
    public async Task<IActionResult> GetDatabase(CancellationToken cancellationToken)
    {
        var canConnect = await dbContext.Database.CanConnectAsync(cancellationToken);

        return canConnect
            ? Ok(new { status = "ok", database = "postgres" })
            : StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                status = "unavailable",
                database = "postgres"
            });
    }
}
