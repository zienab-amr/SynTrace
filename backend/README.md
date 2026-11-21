# SynTrace | GitHub integration

التكامل بيخلّي أدمن الشركة يربط GitHub App، والموظف يربط هويته على GitHub بحسابه داخل SynTrace. المشروع الداخلي في SynTrace هو اللي يجمع مشروع Jira والريبو. الـWorker يسحب التاريخ، يلتقط التحديثات، ويراجع المصدر كل ٦ ساعات. باك إند .NET هو نطاق النسخة دي.

## تشغيل النسخة

1. هذه نسخة من `backend-review.zip` المرفوعة في المحادثة. لو فرع مشروعك على جهازك فيه تغييرات أحدث، ادمجي الملفات الجديدة والمعدلة قبل تشغيل الـmigration. أوامر التشغيل التالية من فولدر `SynTrace.api`.
2. شغّلي SQL Server وRabbitMQ المستخدمين بالفعل في مشروعك. الـAPI والـWorker يحتاجوا نفس قاعدة البيانات والـRabbitMQ virtual host. حددي بيانات الوصول في User Secrets أو متغيرات البيئة لكل عملية.
3. ثبتي أدوات EF إذا لم تكن موجودة، ثم طبقي الـmigration. حددي قاعدة التطوير في متغير البيئة `ConnectionStrings__ConnectionDB` أو مرري `--connection` إلى أمر التحديث. خدي نسخة احتياطية من قاعدة البيانات قبل التحديث على أي بيئة مشتركة.

   ```powershell
   dotnet tool install --global dotnet-ef --version 10.0.13
   dotnet ef database update --project SynTrace.infrastructure --startup-project SynTrace_api
   ```

4. في GitHub App المسمّى `syntrace-integration` اتركي **Request user authorization (OAuth) during installation** مفعّل. اختاري **Any account** لو محتاجة التثبيت على مؤسسة أخرى. اضبطي `Contents` و`Pull requests` على **Read-only** واتركي `Metadata` الإجباري. خلي بقية الصلاحيات على **No access**. ملف الـApp مفيهوش Scope list.
5. ضعي Redirect URI المسجّل في GitHub App على عنوان الباك الحقيقي. أثناء التطوير استخدمي Tunnel يعمل على نفس الـAPI port.

   ```text
   https://YOUR-BACKEND-HOST/api/integrations/github/callback
   ```

6. ضعي القيم السرية محليًا من **Manage User Secrets** في Visual Studio. القيم الموضحة مثال. الـClient Secret الذي سبق مشاركته يحتاج إلغاءه في GitHub واستخدام قيمة جديدة.

   ```json
   {
     "GithubOAuth": {
       "AppId": 5801734,
       "AppSlug": "syntrace-integration",
       "ClientId": "YOUR_CLIENT_ID",
       "ClientSecret": "YOUR_NEW_CLIENT_SECRET",
       "PrivateKeyPath": "E:\\SynTraceSecrets\\syntrace-integration.private-key.pem",
       "RedirectUri": "https://YOUR-BACKEND-HOST/api/integrations/github/callback",
       "FrontendRedirectUri": "",
       "WebhookSecret": "YOUR_RANDOM_WEBHOOK_SECRET"
     }
   }
   ```

   - في الـAPI ضعي كل الحقول السابقة. لما `FrontendRedirectUri` تفضل فاضية، الـcallback يعرض JSON للتجربة. لما الواجهة تكون جاهزة ضعي عنوان صفحة تتعامل مع `status` و`completionId`.
   - في مشروع **SynTrace.Worker** استخدمي نفس `AppId` و`ClientId` و`PrivateKeyPath`، وأضيفي `"GitHubSync": { "Enabled": true }` للإعدادات. الـWorker يستخدم هوية التطبيق للسحب، ولا يحتاج Client Secret أو Redirect URI.
   - اضبطي `ConnectionStrings:ConnectionDB` وإعدادات RabbitMQ في العمليتين. الـAPI يحتاج كمان إعدادات JWT وJira الحالية. القيم القديمة الحساسة حُذفت من ملفات الإعدادات المرفقة. بالنسبة للحاويات اختاري مسار PEM داخل الحاوية عبر read-only bind mount.
   - احتفظي بالـPEM خارج الريبو، واضبطي `PrivateKeyPath` حسب الجهاز. احفظي حلقات مفاتيح ASP.NET Data Protection الحالية لو بتعملي redeploy، لأن Jira يستخدمها لحماية بياناته.

7. شغلي الـAPI والـWorker في نافذتين.

   ```powershell
   dotnet run --project SynTrace_api
   dotnet run --project SynTrace.Worker
   ```

8. بعد الوصول للباك من GitHub فعّلي Webhook في GitHub App. ضعي نفس `WebhookSecret` في إعدادات GitHub والـAPI، واتركي SSL verification شغال. اختاري `Push` و`Pull request` و`Repository`. الـApp يستقبل أحداث دورة التثبيت وإتاحة الريبوز حسب إشعارات GitHub. استعملي الرابط مرة واحدة.

   ```text
   https://YOUR-BACKEND-HOST/api/integrations/github/webhook
   ```

## أول تجربة للأدمن

كل المسارات الخاصة تحتاج Bearer JWT صادر من SynTrace. الأدمن لازم يفضل أدمن فعلًا في قاعدة البيانات. **Create connection** و**install App** عمليتان منفصلتان. تسجيل التثبيت في GitHub يدي التطبيق منحة الوصول، و`complete` يحفظ التثبيت الموافق عليه للشركة داخل SynTrace.

| الخطوة | الطلب | النتيجة |
|---|---|---|
| بدء ربط الشركة | `GET /api/integrations/github/connect` | يرجع `url`. افتحيه في المتصفح واختاري **Only select repositories**. |
| العودة من GitHub | `GET /api/integrations/github/callback` | يرجع `status=confirm` و`completionId`، أو حالة انتظار الموافقة/عدم وجود تثبيت صالح. |
| رؤية التثبيت المتحقق منه | `GET /api/integrations/github/pending?completionId=...` | يرجع حساب GitHub والتثبيتات التي تحقّق منها الباك. |
| تأكيد ربط الشركة | `POST /api/integrations/github/complete` | ارسلي `{"completionId":"...","installationId":123456}` باستخدام **نفس حساب SynTrace**. يرجع 204. |
| عرض الريبوز | `GET /api/integrations/github/repositories` | يعرض الريبو الذي تسمح به منحة التثبيت وصلاحية الربط. |
| تجهيز المشروع | `POST /api/projects` | لو المشروع مش موجود، ابعتي `{"clientId":"...","name":"Payments","description":"..."}`. يحتاج عميلًا موجودًا في نفس الشركة. |
| ربط Jira | `GET /api/projects/jira-options` ثم `PUT /api/projects/{projectId}/jira` | ابعتي `{"jiraProjectId":"..."}` باستخدام المعرف الداخلي من القائمة. |
| ضم موظف للمشروع | `PUT /api/projects/{projectId}/members/{employeeId}` | يقدر يشوف نشاط المشروع بعد ضمه. |
| ربط الريبو | `PUT /api/integrations/github/projects/{projectId}/repository` | ابعتي `{"repositoryId":123456}` من قائمة الريبوز. تبدأ المزامنة من حالة pending. |
| متابعة السحب | `GET /api/integrations/github/projects/{projectId}` | الربط، حالة السحب وآخر نجاح. |
| فتح النشاط | `GET /api/projects/{projectId}/github/activity?kind=pull_request&offset=0` | أحدث البيانات المحفوظة مع الروابط إلى Jira. جربي `kind=commit` للـcommits. |

لو التثبيت اتعمل مسبقًا أو وافق عليه أدمن الـOrganization لاحقًا، استخدمي `GET /api/integrations/github/authorize-company` وكملي من `pending` و`complete`. ربط التثبيت بيستخدم الوصول المثبت للمستخدم على GitHub والتحقق بهوية التطبيق. في الـOrganization يُحفظ نطاق الريبوز التي تحققنا أن مسؤول الربط يقدر يديرها. إعادة التفويض مطلوبة لإضافة ريبوز خارج النطاق ده.

## تجربة الموظف والربط مع Jira

1. الموظف يسجّل دخول إلى SynTrace بنفس الأكونت الذي استخدمه لربط Jira الشخصي.
2. يستدعي `GET /api/integrations/github/connect-employee` ويفتح `url`.
3. بعد الرجوع إلى callback يأخذ `completionId` ويعرض الحساب عبر `GET /api/integrations/github/pending?completionId=...`.
4. يؤكد `POST /api/integrations/github/complete` باستخدام `{"completionId":"..."}`. اختيار Installation ID خاص بالشركة.
5. `GET /api/integrations/identities/me` يرجع `github.userId` و`jira.accountId` و`linkedTogether`. النتيجة تصبح true لما الربطين المؤكدين موجودين لنفس `EmployeeId` ونفس الشركة وJira site الحالي. تشابه الأسماء والإيميل غير مستخدم في الربط. بيانات Jira المتضاربة تحتاج تصحيح الربط قبل اعتماد المطابقة.
6. في الـActivity الباك يطابق `authorId` و`mergedById` مع الهويات الموثقة، ويربط مفاتيح مثل `PAY-42` عندما توجد التذكرة بالفعل داخل مشروع Jira المربوط في نفس الشركة. المفتاح المفقود أو الغامض يظهر unresolved. لكل من حالة Jira وحالة الـPR معناها المستقل.

الفصل اليدوي عبر `DELETE /api/integrations/github/company` أو `DELETE /api/integrations/github/employee`. لفك ريبو مشروع استخدمي `DELETE /api/integrations/github/projects/{projectId}/repository`. لإعادة السحب استخدمي `POST /api/integrations/github/projects/{projectId}/sync`. فصل الربط في SynTrace يوقف الوصول المحلي وينظف المصدر، وإزالة التثبيت من GitHub تظل خطوة مستقلة في إعدادات الحساب.

## تدفق البيانات بالتفصيل

- **OAuth State.** `OAuthStateRepository` مشتركة بين Jira وGitHub. تحفَظ SHA-256 للـstate المولّد عشوائيًا مع الشركة والموظف والمزوّد والغرض ووقت انتهاء خمس دقائق. تحديث شرطي في SQL يستهلكه مرة واحدة. مسارات Jira تبقى منفصلة عن GitHub على أساس المزوّد. عند الانتقال، تُنقل الـstates الموجودة من الجدول القديم. استخدام PKCE في مسارات تفويض GitHub المباشر يحمي التبادل، والـverifier محمي بـData Protection.
- **تأكيد الحساب.** الباك يتبادل الكود بـUser Access Token على السيرفر ويتحقق من الهوية والتثبيت. النتيجة القابلة للتأكيد تبقى محفوظة كمعرّف عشوائي محفوظ بالهاش لمدة خمس دقائق، ولا تظهر بيانات التوكن في الرد أو قاعدة البيانات. الطلب النهائي يحتاج JWT لنفس الشركة والموظف. توكن سحب الريبوز Installation Access Token قصير العمر، يصدر باستخدام المفتاح الخاص وتثبيت الشركة ويُقيّد بالريبو عند السحب.
- **Backfill.** يبدأ تلقائيًا عند ربط الريبو. يُحفظ تقدّم كل صفحة في SQL. الاستيراد يشمل تاريخ commits المتاح من الفرع الافتراضي، كل صفحات الـPRs، وحالة الـPR والدمج، ومعلومات الملفات التي تغيرت حسب حدود GitHub. الكود الحالي يقرأ عند SHA ثابت. محتوى الفروع غير الافتراضية يظهر من بيانات الـPRs المرتبطة، ولا توجد فهرسة لنسخ كل ملف عند كل commit. GitHub له حدود على تفاصيل PR حتى مع pagination، والـpayload يحمل أعلام عدم اكتمال لما يتوفر دليل عليها.
- **حدود الكود.** افتراضيًا 500 ملف، 64 KiB لكل ملف، و8 MiB للنسخة. الكود النصي المسموح فقط، مع استبعاد ملفات حساسة واعتمادات ومخرجات بناء وملفات ثنائية، وتنقيح أنماط أسرار شائعة قبل التخزين والإرسال. قواعد الحجب تساعد لكنها لا تضمن التقاط كل صيغة سر. استخدمي ريبو اختبار خالي من أسرار حقيقية. ما بيتعملش build أو execution للكود المستورد.
- **Webhook.** الباك يتحقق من HMAC على البايتات الأصلية ومن installation/repository، ويسجل Delivery ID فريد في SQL قبل 202. يسجّل معلومات التوجيه اللازمة بدل جسم الـevent الخام. الـdispatcher ينشر المعرف في Rabbit بتأكيد نشر. الـconsumer يرجع للسجل ويطلب تحديث الريبو. التكرار أو إعادة التسليم لا ينشئ نسخة مكررة من نفس الحدث. فيه retries بتأخير وdead-letter بعد محاولات محدودة. الرسائل المشغّلة للسحب منفصلة عن queue Jira.
- **التحديث والمراجعة.** إشعارات Push وPR بتطلّب نسخة حديثة من GitHub. كل ريبو يحتفظ بموعد مراجعة بعد ست ساعات من نجاح دورة المزامنة. ده يستدرك التحديثات الفائتة لو GitHub لم يوصل webhook. الـWorker يحترم Retry-After أو وقت فك rate limit، ويعيد المحاولة بعد الأخطاء المؤقتة. ملفات الكود تُحدّث عند تغيير SHA، والملفات المحذوفة تُستبعد من النسخة الحالية. فك الربط يمنع العرض ويطلب تنظيف مسار بيانات التثبيت/الريبو.
- **المتانة.** بيانات الريبو ودفعات التغيير تتسجل في نفس المعاملة مع outbox. المصدر الثابت للربط هو `bindingId`، ومعه `sourceVersion` متزايد للأحداث. لو RabbitMQ تعطل، سجل التغيير يفضل في SQL. قد تتكرر الرسالة بعد تأكيد النشر وقبل تسجيل الإقرار، لذلك المستهلك يحتاج dedup.
- **تسليم AI.** الـ.NET ينشر رسائل مُنظّمة في `syntrace.ai.github` على exchange `syntrace.github.events` وrouting key `github.ai.v1`. فيها `schemaVersion` و`eventId` و`companyId` و`projectId` و`bindingId` و`repositoryId` و`entityId` و`sourceVersion` و`payload`. تشمل upserts للريبو والـcommit والـPR والملف، وإزالة ملفات، وإكمال السحب، وإلغاء الريبو. على AI consumer التحقق من عزل المصادر، إزالة الفهرس والكاش عند revocation، وحفظ إشارات الملف والـSHA للمراجع. حالة synced في الباك تعني نجاح استيراد الباك، ولا تقيس اكتمال embedding.
- **حد التسليم.** مجلد AI/Flutter لم يكن جزءًا من نسخة الباك. التغييرات تجهز الربط والـAPIs ورسائل البيانات. فهرسة Neo4j وعرض الشاشات داخل Flutter يحتاجان توصيل القطعتين في مشاريعهما.

## اختبارات التطوير

```powershell
dotnet build SynTrace.api.slnx
dotnet run --project SynTrace.IntegrationChecks
dotnet ef migrations has-pending-model-changes --project SynTrace.infrastructure --startup-project SynTrace_api
```

استخدمي ريبو اختبار، اربطيه بمشروع Jira فيه تذكرة معروفة، واعملِي PR باسم `PAY-42 Add checkout validation`. بعد وصول التحديث شوفي الحالة من الـActivity. جرّبي إعادة إرسال نفس الـdelivery من Recent Deliveries، ثم فك الربط وشوفي إن النشاط مبقاش متاح. جرّبي الحالتين بدور أدمن وبدور موظف مضاف للمشروع.

## تحقق النسخة المرفقة

نجح بناء الـsolution كاملة على .NET 10، وعدّت اختبارات SQLite وواجهات GitHub الوهمية لجدول OAuth المشترك، وربط الشركة والموظف، والـwebhook، والـbackfill والمراجعة وإلغاء صلاحية الريبو. أكد EF توافق الـmigration مع الموديل، وولّدنا سكربت SQL قابلًا لإعادة التشغيل. اختبار GitHub الحقيقي وتسليم الرسائل على RabbitMQ وتشغيل السكربت على SQL Server الخاص بك يحتاج تشغيل البيئة عندك.

## نسخة إصلاحات مراجعة الباك

اشتغلي من نسخة جديدة من الحزمة. لو عندك تعديلات أحدث من نسخة الباك اللي شاركتيها، ادمجيها قبل استخدام الحزمة. ابدئي بقاعدة تطوير وخدي نسخة احتياطية قبل تحديث قاعدة فيها بيانات. لا تحتوي الحزمة أسرار التشغيل. إعداد Docker وخدمة الترقية موجودين في `DEPLOYMENT.md`.

- عمليات إدارة العملاء والموظفين والأدوار تعتمد على حساب أدمن ما زال مخصصًا للشركة في قاعدة البيانات. الـAPI يُرجع DTOs للموظفين. تغيير الدور يتم داخل الشركة على الـrole الموثق. تعديل العميل يستخدم المعرف المكتوب في الرابط.
- إعادة تعيين كلمة السر تستخدم OTP مخصص للغرض ويستهلك مرة واحدة عند النجاح. تسجيل الحساب له غرض وإثبات منفصل. تغيير الباسورد وإدارة أدوار الموظف يجددان Security Stamp ويُبطلان الجلسات المرتبطة بالموظف. **بعد ترقية النسخة، كل المستخدمين يسجلوا دخول من جديد** حتى يحصلوا على JWT بالعقد الجديد.
- العضو يستخدم الـAssistant في المشاريع اللي هو عضو فيها، والأدمن على مستوى شركته. افتراضيًا بيتبعت `allowedProjects` وفيه مفاتيح مشاريع Jira المرتبطة. بعد ما فريق الـAI يدعم `allowedSynTraceProjectIds` ويطبق القائمتين أثناء البحث، فعّلي `AiService:EnableSynTraceProjectScope` أو `SYNTRACE_AI_PROJECT_SCOPE=true` مع Compose عشان الأسئلة تشمل GitHub والمصادر المعتمدة حتى في مشروع من غير Jira. أي قائمة فاضية تمنع الوصول للنوع المقابل من المصادر.
- `GET /health/live` يتحقق من حياة الـAPI، و`GET /health/ready` يتحقق من SQL Server وRabbitMQ. `GET /api/audit` للأدمن يقرأ سجل طلبات التعديل داخل الشركة. السجل فيه المسار العام، صاحب الطلب، والوقت والحالة. لو كتابة السجل فشلت، الخطأ يظهر في لوج التشغيل مستقلاً عن العملية التي قد تكون خلصت بالفعل.
- SignalR متاح على `/hubs/project-status`. وصلي الـJWT باستخدام `accessTokenFactory` من العميل، ونادي `WatchProject(projectId)`. الحدث `ProjectStatusChanged` بيعرض المشاريع المصرح بها وحالة المزامنة، عن طريق قراءة حالتها كل خمس ثوانٍ أثناء الاشتراك. `UnwatchProject(projectId)` يلغي الاشتراك. يُغلق الاتصال عند انتهاء التوكن. لو Flutter Web أو الواجهة على origin مختلف، حدديه في إعداد الباك `Cors:FrontendOrigins:0`، أو متغير البيئة `Cors__FrontendOrigins__0` عند التشغيل المباشر، مثل `https://syntrace.example`.
- `GET /api/projects/{projectId}` و`PUT /api/projects/{projectId}` لقراءة وتعديل المشروع. للإيقاف استخدمي حالة `Archived`. الأدمن يغير دور عضو باستخدام `PUT /api/projects/{projectId}/members/{employeeId}?role=ProductOwner`، أو `ProjectManager` أو `Member`. الحذف من الفريق من خلال `DELETE` على نفس رابط العضوية.
- المعالجة المركزية ترجع Problem Details للأخطاء المتوقعة، و400 للتحقق من الـDTO والأوامر التي تستخدم Data Annotations. أخطاء السيرفر ترجع معرّف تتبع، والتفاصيل الحساسة تفضل خارج الرد.

شغّلي مع الفرق الأخرى اختبارًا متكاملًا على قاعدة اختبار. ارفعي متطلبًا أو ملاحظة اجتماع، راجعي الأدلة المستخرجة، ثم اسألي عن تذكرة Jira لها PR في GitHub ومصدر معتمد. الـAI والواجهة موجودين في مشاريع مستقلة، وتوصيل معالجة المستندات والبحث وعرض SignalR يحتاج تطبيق العقد عندهم.

### تحديث الواجهة بعد الترقية

لنسيان كلمة السر، اطلبي الكود من `POST /api/Auth/send-otp` بجسم `{"request":{"email":"…","purpose":"passwordReset"}}`. ابعتي نفس الكود في `POST /api/Auth/reset-password` داخل `request` مع `email` و`newPassword` و`confirmPassword`. الكود صالح لخمس دقايق وبيُستهلك بعد نجاح التغيير. المحاولات وإعادة الإرسال عليهم حد.

لتسجيل شركة جديدة، استخدمي `purpose: "registration"`. لو الواجهة فيها خطوة `POST /api/Auth/verify-otp`، خدي `verificationToken` من الرد وابعتيه داخل `request` في `POST /api/Auth/register`. ممكن كمان تبعتي `otp` مباشرة في التسجيل إذا الكود لسه صالح ولم يتم التحقق منه. لتعديل الحساب الشخصي، استخدمي `GET/PUT /api/Employee/me`. إدارة الأدوار تقبل `roleId` و`newRoleId` و`previousRoleId` حسب العملية.

### المستندات والمتطلبات والاجتماعات

راجعي `KNOWLEDGE-SOURCES.md` لأمثلة الرفع وسير المراجعة. اجتماع أول مرة مع عميل ممكن يتسجل على العميل ويرتبط بمشروعه بعد الإنشاء. ملاحظات الاجتماع الأونلاين تقبل النص أو الـtranscript اللي ترفعيه. جداول الملاحظات القديمة محفوظة في قاعدة البيانات. واجهة المصادر الجديدة تبدأ بإدخالاتها الخاصة، وترحيل أي ملاحظات قديمة إليها يحتاج مراجعة وربطها بسياقها الصحيح. تحليل PDF والفهرسة يتفعّلان بعد توصيل خدمة الـAI بعقد التسليم.

### مزامنة Jira بعد الترقية

أحداث إنشاء وتعديل المشروع تحدّث SQL. أحداث الحذف الواردة بعد الترقية تسجّل وقت الحذف عشان الـwebhook المتأخر أو نتائج السحب القديمة ما ترجعش عنصر محذوف. مسار إعادة محاولة Jira والـDead Letter ينتظر تأكيد RabbitMQ على النشر قبل ACK للرسالة الأصلية. المستهلك يعالج الرسائل المكررة بطريقة آمنة.

في نسخة التطوير، اختبارات SQLite وواجهات HTTP الوهمية بتغطي صلاحيات الحسابات والشات، ومصادر المعرفة، وJira وGitHub. شغّلي أول تجربة فعلية على قاعدة اختبار قبل تبديل بيئة مشتركة.
