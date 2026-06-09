namespace Fildir.Domain.Constants;

public static class LocationPolicy
{
    public const double AnkaraCenterLatitude = 39.92077;
    public const double AnkaraCenterLongitude = 32.85411;
    public const double AnkaraDetectionRadiusKm = 85;
    public const double AnkaraMaxVisibleRadiusKm = 50;
    public const double DefaultRadiusKm = 5;
    public const int DefaultFeedLimit = 40;
    public const int MaxFeedLimit = 100;

    public static readonly double[] AnkaraRadiusOptionsKm = [1, 3, 5, 10, 25, 50];

    public static bool IsLocationInAnkara(double latitude, double longitude)
    {
        return DistanceKmBetween(
            latitude,
            longitude,
            AnkaraCenterLatitude,
            AnkaraCenterLongitude) <= AnkaraDetectionRadiusKm;
    }

    public static double EffectiveRadiusKm(
        double requestedRadiusKm,
        double latitude,
        double longitude)
    {
        if (!IsLocationInAnkara(latitude, longitude))
        {
            return AnkaraRadiusOptionsKm[0];
        }

        if (AnkaraRadiusOptionsKm.Contains(requestedRadiusKm))
        {
            return requestedRadiusKm;
        }

        var allowedRadius = AnkaraRadiusOptionsKm
            .Where(option => option <= requestedRadiusKm)
            .DefaultIfEmpty(AnkaraRadiusOptionsKm[0])
            .Max();

        return allowedRadius;
    }

    public static double DistanceKmBetween(
        double fromLatitude,
        double fromLongitude,
        double toLatitude,
        double toLongitude)
    {
        const double earthRadiusKm = 6371.0;
        var lat1 = DegreesToRadians(fromLatitude);
        var lat2 = DegreesToRadians(toLatitude);
        var deltaLat = DegreesToRadians(toLatitude - fromLatitude);
        var deltaLon = DegreesToRadians(toLongitude - fromLongitude);

        var a =
            Math.Sin(deltaLat / 2) * Math.Sin(deltaLat / 2) +
            Math.Cos(lat1) *
            Math.Cos(lat2) *
            Math.Sin(deltaLon / 2) *
            Math.Sin(deltaLon / 2);

        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));

        return earthRadiusKm * c;
    }

    private static double DegreesToRadians(double degrees)
    {
        return degrees * Math.PI / 180;
    }
}
