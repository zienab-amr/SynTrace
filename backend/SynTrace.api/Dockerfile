
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy solution and project files
COPY ["SynTrace.api.slnx", "./"]
COPY ["SynTrace_api/SynTrace_api.csproj", "SynTrace_api/"]
COPY ["SynTrace.application/SynTrace.Application.csproj", "SynTrace.application/"]
COPY ["SynTrace.infrastructure/SynTrace.Infrastructure.csproj", "SynTrace.infrastructure/"]
COPY ["SynTrace.Domain/SynTrace.Domain.csproj", "SynTrace.Domain/"]
COPY ["SynTrace.Contracts/SynTrace.Contracts.csproj", "SynTrace.Contracts/"]

# Restore dependencies
RUN dotnet restore "SynTrace_api/SynTrace_api.csproj"

# Copy source code
COPY . .

# Publish API
RUN dotnet publish "SynTrace_api/SynTrace_api.csproj" \
    -c Release \
    -o /app/publish \
    --no-restore

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "SynTrace_api.dll"]
