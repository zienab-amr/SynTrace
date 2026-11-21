# تشغيل باك إند SynTrace

## Docker Compose للتطوير

- شغّلي Docker Desktop أو Docker Engine مع Compose v2. SQL Server يستخدم صورة Linux x86_64 ويحتاج حوالي 2 GB RAM على الأقل لنفسه.
- انسخي `.env.example` إلى `.env` بجوار `compose.yaml`. اختاري كلمة سر قوية للتطوير لكل من SQL وRabbitMQ ومفتاح JWT عشوائي لا يقل عن 32 بايت. استخدمي متغيرات SMTP وJira حسب المزايا التي ستجربيها. ملف `.env` وملفات `.pem` مستبعدة من Git.
- كلمة سر SQL يلزمها حروف كبيرة وصغيرة وأرقام أو رموز ليقبلها SQL Server. اختاري قيمة بدون علامات اقتباس مزدوجة لتتوافق مع صيغة connection string في Compose.

من فولدر الباك الرئيسي:

```powershell
docker compose up --build -d
docker compose ps -a
docker compose logs migrate
```

تبدأ SQL Server وRabbitMQ، ثم ينتظر `migrate` صحة SQL Server ويطبق migrations. الـAPI والـWorker ينتظران نجاحها وجاهزية RabbitMQ. خدمة `migrate` من الطبيعي أن تكون `Exited (0)` بعد انتهاء عملها. استخدمي مجلد بيانات محلي جديد للتجربة الأولى. الأمر `docker compose down` يوقف الحاويات ويحافظ على بيانات SQL وRabbitMQ ومفاتيح Data Protection.

| جزء | تشغيل التطوير |
| --- | --- |
| API | `http://localhost:8080` |
| Health | `http://localhost:8080/health/live` و`http://localhost:8080/health/ready` |
| RabbitMQ management | `http://localhost:15672` والمستخدم `syntrace` |
| SQL Server | متاح للـAPI والـWorker داخل شبكة Compose |
| AI | خدمة منفصلة. اضبطي `SYNTRACE_AI_BASE_URL` و`SYNTRACE_AI_API_KEY` إذا كانت متاحة. |

لو الـAI شغال على جهازك خارج Docker، عنوان مثل `http://host.docker.internal:8000/` يوصل له من حاوية الـAPI بشرط أن يكون السيرفر قابلًا للوصول من شبكة Docker. غيّري المنفذ حسب خدمتك.

## تفعيل GitHub داخل Compose

في ملف `.env` اكتبي إعدادات تطبيق GitHub، وعنوان الـAPI العام في callback، و`SYNTRACE_GITHUB_PRIVATE_KEY_FILE` كمسار حقيقي لملف المفتاح الخاص خارج المشروع. لو المسار على Windows، اكتبيه بشرطات مائلة `/` مثل `E:/SynTraceSecrets/syntrace-integration.private-key.pem`.

```powershell
docker compose -f compose.yaml -f compose.github.yaml up --build -d
docker compose -f compose.yaml -f compose.github.yaml logs -f api worker
```

الملف الإضافي يركّب مفتاح GitHub داخل الـAPI والـWorker كـsecret ويضبط المسار داخل الحاوية ويفعّل السحب في الـWorker. الـWebhook secret وOAuth client secret يصلان للـAPI من إعدادات التشغيل. للروابط والخطوات التفصيلية ارجعي إلى `README.md`. حددي HTTPS لعنوان GitHub العام، سواء خلف reverse proxy أو باستخدام tunnel في التطوير.

ملفات Compose دي للتطوير. تشغيل بيئة مشتركة يحتاج إعداد HTTPS وصلاحيات SQL أقل من `sa` وإدارة مفاتيح وبيانات اعتماد خاصة بالبيئة. خدي نسخة احتياطية قبل تنفيذ migration على قاعدة فيها بيانات.

## الاختبارات وCI

من فولدر `SynTrace.api`:

```powershell
dotnet restore SynTrace.api.slnx -p:NuGetAuditMode=all
dotnet build SynTrace.api.slnx --no-restore
dotnet run --project SynTrace.IntegrationChecks --no-build --no-restore
```

ملف `.github/workflows/ci.yml` في جذر الريبو يشغّل تدقيق مكتبات NuGet المباشرة والمتعدية، والبناء والاختبارات، ويتحقق من مطابقة migrations لموديل EF. إعداد GitHub Branch Protection هو الذي يجعل نجاح الـworkflow شرطًا للدمج.

## Compose في جذر الريبو

ملف `docker-compose.yml` في جذر الريبو يستخدم `.env.example` الموجود بجانبه، وقاعدة `SynTraceDB` والـAPI على `http://localhost:8081`. خدمة `migrate` تطبق migrations بعد جاهزية SQL، ثم يبدأ الـAPI والـWorker بعد نجاحها وجاهزية RabbitMQ.

لتجربة تكامل GitHub استخدمي ملفات Compose وإعدادات `.env` داخل `backend` حسب الخطوات أعلاه. الإعداد ده يستخدم قاعدة تطوير باسم `SynTrace` والـAPI على المنفذ 8080 افتراضيًا. شغّلي مجموعة واحدة كل مرة لتجنب تعارض المنافذ مثل RabbitMQ Management على 15672.
