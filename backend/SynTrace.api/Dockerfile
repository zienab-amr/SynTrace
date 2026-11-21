# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy solution and project files
COPY ["SynTrace.api.slnx", "./"]
COPY ["SynTrace_api/SynTrace.Api.csproj", "SynTrace_api/"]
COPY ["SynTrace.application/SynTrace.Application.csproj", "SynTrace.application/"]
COPY ["SynTrace.infrastructure/SynTrace.Infrastructure.csproj", "SynTrace.infrastructure/"]
COPY ["SynTrace.Domain/SynTrace.Domain.csproj", "SynTrace.Domain/"]
COPY ["SynTrace.Contracts/SynTrace.Contracts.csproj", "SynTrace.Contracts/"]

# Restore dependencies
RUN dotnet restore "SynTrace_api/SynTrace.Api.csproj"

# Copy source code
COPY . .

# Publish API
RUN dotnet publish "SynTrace_api/SynTrace.Api.csproj" \
    -c Release \
    -o /app/publish \
    --no-restore

# SDK target used by the one-time migration job in local Compose.
FROM build AS migrate
RUN dotnet tool install dotnet-ef --tool-path /tools --version 10.0.13
ENTRYPOINT ["/tools/dotnet-ef", "database", "update", "--project", "SynTrace.infrastructure", "--startup-project", "SynTrace_api", "--configuration", "Release", "--no-build"]

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "SynTrace.Api.dll"]
