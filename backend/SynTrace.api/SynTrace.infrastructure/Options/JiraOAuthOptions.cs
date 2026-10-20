using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Infrastructure.Options
{
    public class JiraOAuthOptions
    {
        public string AuthorizationUrl { get; set; }
        public string TokenUrl { get; set; }
        public string RedirectUri { get; set; }
        public string Audience { get; set; }
        public string ClientId { get; set; }
        public string ClientSecret { get; set; }
        public List<string> Scopes { get; set; }
    }
}