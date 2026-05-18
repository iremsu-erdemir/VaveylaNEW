using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using Vaveyla.Api.Data;
using Vaveyla.Api.Diagnostics;
using Vaveyla.Api.Hubs;
using Vaveyla.Api.Models;
using Vaveyla.Api.Services;
using Vaveyla.Api.Services.Recommendations;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<JwtSettings>(
    builder.Configuration.GetSection(JwtSettings.SectionName));
builder.Services.Configure<ImageModerationOptions>(
    builder.Configuration.GetSection(ImageModerationOptions.SectionName));
builder.Services.AddScoped<IJwtService, JwtService>();

var jwtKey = builder.Configuration["Jwt:Key"] ?? "Vaveyla-DefaultKey-Min32CharactersRequired!!";
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "VaveylaApi";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "VaveylaApp";

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            ClockSkew = TimeSpan.Zero,
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddControllers().AddJsonOptions(options =>
{
    options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    options.JsonSerializerOptions.Converters.Add(
        new JsonStringEnumConverter(JsonNamingPolicy.CamelCase, allowIntegerValues: true));
});
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddDbContext<VaveylaDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Default")));
builder.Services.Configure<EmailSettings>(builder.Configuration.GetSection("Email"));
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IFeedbackRepository, FeedbackRepository>();
builder.Services.AddScoped<IFeedbackAppService, FeedbackAppService>();
builder.Services.AddScoped<IUserSuspensionService, UserSuspensionService>();
builder.Services.AddExceptionHandler<ForbiddenOperationExceptionHandler>();
builder.Services.AddProblemDetails();
builder.Services.AddHostedService<SuspensionExpirationHostedService>();
builder.Services.AddScoped<IPasswordResetEmailSender, SmtpPasswordResetEmailSender>();
builder.Services.AddScoped<IRestaurantOwnerRepository, RestaurantOwnerRepository>();
builder.Services.AddScoped<ICustomerOrdersRepository, CustomerOrdersRepository>();
builder.Services.AddScoped<IDeliveryChatRepository, DeliveryChatRepository>();
builder.Services.AddScoped<ICustomerCartRepository, CustomerCartRepository>();
builder.Services.AddScoped<ICustomerReviewsRepository, CustomerReviewsRepository>();
builder.Services.AddScoped<ICustomerChatsRepository, CustomerChatsRepository>();
builder.Services.AddScoped<INotificationRepository, NotificationRepository>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<IPushNotificationSender, NoopPushNotificationSender>();
builder.Services.AddScoped<ICartCalculationService, CartCalculationService>();
builder.Services.AddScoped<ICampaignRepository, CampaignRepository>();
builder.Services.AddScoped<ICouponRepository, CouponRepository>();
builder.Services.AddScoped<ICouponService, CouponService>();
builder.Services.AddMemoryCache();
builder.Services.AddScoped<IProductRepository, ProductRepository>();
builder.Services.AddScoped<IOrderRepository, OrderRepository>();
builder.Services.AddScoped<IRecommendationQueryService, RecommendationQueryService>();
builder.Services.AddSingleton<IRecommendationScoringService, RecommendationScoringService>();
builder.Services.AddScoped<IRecommendationComposer, RecommendationComposer>();
builder.Services.AddScoped<IRecommendationService, RecommendationService>();
builder.Services.AddHttpClient(nameof(GoogleVisionImageModerationService));
builder.Services.AddScoped<IImageModerationService, GoogleVisionImageModerationService>();
builder.Services.AddSignalR();
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy
            .AllowAnyOrigin()
            .AllowAnyHeader()
            .AllowAnyMethod()
            .WithExposedHeaders("*"));
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

if (app.Environment.IsProduction())
{
    app.UseHttpsRedirection();
}

app.UseExceptionHandler();
app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();
app.UseStaticFiles();

app.MapControllers();
app.MapHub<NotificationHub>("/hubs/notifications");
app.MapHub<TrackingHub>("/hubs/tracking");

using (var scope = app.Services.CreateScope())
{
    try
    {
        var db = scope.ServiceProvider.GetRequiredService<VaveylaDbContext>();
        await db.Database.MigrateAsync();
        await DbSeeder.SeedAsync(db);
    }
    catch (Exception ex)
    {
        var logger = scope.ServiceProvider.GetService<ILogger<Program>>();
        logger?.LogWarning(ex, "Veritabanı migration/seed aşamasında hata. API çalışmaya devam ediyor.");
    }
}

app.Run();
