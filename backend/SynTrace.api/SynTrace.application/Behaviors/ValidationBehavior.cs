using System.ComponentModel.DataAnnotations;
using MediatR;

namespace SynTrace.Application.Behaviors;

public sealed class RequestValidationException(IReadOnlyDictionary<string, string[]> errors)
    : Exception("One or more request fields are invalid.")
{
    public IReadOnlyDictionary<string, string[]> Errors { get; } = errors;
}

public sealed class ValidationBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        var results = new List<ValidationResult>();
        if (!Validator.TryValidateObject(request, new ValidationContext(request), results, validateAllProperties: true))
        {
            var errors = results.SelectMany(r => r.MemberNames.DefaultIfEmpty(string.Empty)
                    .Select(field => (field, message: r.ErrorMessage ?? "Invalid value.")))
                .GroupBy(r => r.field)
                .ToDictionary(g => g.Key, g => g.Select(r => r.message).Distinct().ToArray());
            throw new RequestValidationException(errors);
        }
        return next(cancellationToken);
    }
}
