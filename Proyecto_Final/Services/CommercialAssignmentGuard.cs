namespace Proyecto_Final.Services;

public sealed class CommercialAssignmentsUnavailableException() : InvalidOperationException(
    "Las relaciones vendedor-cliente y supervisor-vendedor no están acreditadas.") { }

public static class CommercialAssignmentGuard
{
    // No configuration switch or administrator exception can manufacture a relationship.
    // Replace only when canonical assignments and their authorization policy are approved.
    public static void RequireAccreditedRelations() => throw new CommercialAssignmentsUnavailableException();
}
