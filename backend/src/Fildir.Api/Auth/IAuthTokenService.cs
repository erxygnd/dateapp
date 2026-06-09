using Fildir.Domain.Entities;

namespace Fildir.Api.Auth;

public interface IAuthTokenService
{
    TokenPair CreateTokenPair(AppUser user);

    string HashRefreshToken(string refreshToken);
}
