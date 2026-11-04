# SynTrace AI

الجزء ده بيحوّل بيانات Jira لـ knowledge graph في Neo4j، وبيجاوب على أسئلة المستخدمين بـ GraphRAG. كل شركة بياناتها منفصلة.

## Architecture

```
Jira → Backend (.NET) → RabbitMQ (syntrace.events) → syntrace.ai.jira → ai_consumer.py → Neo4j
Flutter → Backend → POST /ask → ai_service.py → Neo4j + Ollama (bge-m3) + Groq
```

| الملف | الدور |
| --- | --- |
| `ai_consumer.py` | بيستقبل الـ events والـ import من RabbitMQ |
| `ai_service.py` | `POST /ask` و`GET /health` |
| `webhook_handler.py`, `event_adapter.py`, `event_reliability.py` | معالجة الـ Jira webhook |
| `ingest.py`, `field_catalog.py`, `adf_parser.py` | تحويل الـ issue لـ graph، والمسح |
| `query_engine.py`, `semantic_search.py`, `embeddings.py`, `answer_generator.py` | الـ retrieval والإجابة |
| `setup_constraints.py` | الـ constraints والـ indexes في Neo4j |
| `build_graph.py`, `build_embeddings.py`, `check_graph.py`, `verify_graph.py`, `evaluate_graphrag.py` | أدوات محلية للبناء والتقييم |

## التشغيل

المطلوب: Python 3.11+، وNeo4j 5، وRabbitMQ، وOllama، وGroq API key.

```powershell
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
ollama pull bge-m3
copy .env.example .env      # واملا القيم
python setup_constraints.py

uvicorn ai_service:app --host 0.0.0.0 --port 8000
python ai_consumer.py
```

الـ service لازم تفضل على الـ network الداخلية، والـ backend بس هو اللي يكلمها.

## التشغيل بـ Docker

المطلوب: Docker Desktop على جهاز الـ AI بس. RabbitMQ شغال على جهاز الـ backend.

```powershell
copy .env.example .env      # واملا NEO4J_PASSWORD وGROQ_API_KEY وAI_API_KEY وRABBITMQ_HOST وRABBITMQ_USER وRABBITMQ_PASSWORD وAI_BIND_ADDRESS
docker compose up -d --build
docker compose ps
```

الـ backend بينادي `http://<AI_BIND_ADDRESS>:8000/ask`. ولو RabbitMQ مش متاح، `ai-consumer` بيعيد المحاولة كل 10 ثواني.

**تحميل الداتا المحلية للتجربة** (في PowerShell، ولازم `TENANT_ID` و`ALLOWED_PROJECTS` في `.env`):

```powershell
docker compose run --rm -v "${PWD}/all_tickets:/app/all_tickets:ro" -v "${PWD}/field_meta.json:/app/field_meta.json:ro" ai-service python build_graph.py
docker compose run --rm ai-service python build_embeddings.py
docker compose run --rm ai-service python check_graph.py
```

| الأمر | بيعمل إيه |
| --- | --- |
| `docker compose logs -f ai-consumer` | يعرض الـ logs |
| `docker compose down` | يوقف الخدمات، والبيانات بتفضل |
| `docker compose down -v` | **يمسح كل البيانات** |

## الـ contract

**`POST /ask`** بـ header اسمه `X-Internal-Api-Key`:

```json
{ "question": "مين المسؤول عن SYNTECH-5؟", "companyId": "...", "employeeId": "...", "allowedProjects": ["SYNTECH"] }
```

```json
{ "status": "ok", "answer": "...", "links": [{ "key": "SYNTECH-5", "url": "..." }], "correlationId": "..." }
```

`status` قيمته `ok` أو `not_found` أو `no_results`. الـ `503` معناه إن الـ service أو الـ search مش متاحين.

**RabbitMQ:** الـ envelope فيه `eventId` و`eventType` و`companyId` و`cloudId` و`siteUrl`.

| `eventType` | اللي بيتقرا | اللي بيحصل |
| --- | --- | --- |
| Jira events | `rawWebhook` | تحديث الـ graph أو المسح |
| `FieldCatalog` | `payload.fields` | حفظ الـ custom fields للشركة |
| `IssueSnapshot` | `payload` (Jira issue كامل) | تخزين التذكرة |
| `ImportCompleted` | | تشغيل بناء الـ embeddings في الخلفية، من غير ما يعطل باقي الـ events |
| `CompanyDisconnected` | | مسح كل بيانات الشركة |

الفشل المؤقت بيروح `syntrace.ai.retry` بـ routing key `retry`، والفشل النهائي بيروح `syntrace.ai.dlx` بـ routing key `dead`.

## قرارات

- **المسح hard delete من غير أي أثر.** المخاطرة المقبولة إن webhook متأخر ممكن يرجع عنصر ممسوح.
- **مفيش sync دوري للـ AI:** import أول مرة، وبعدها webhooks.
- **الـ attachments:** بنخزن الـ metadata بس، ومحتوى الملفات لسه مش بيتقرا.
- **`SAVE_RAW_EVENTS` و`JOURNAL_FAILED_EVENTS`** لازم يفضلوا مقفولين في الـ production.

## الاختبارات

```powershell
pip install -r requirements-dev.txt
python test_offline.py
python -m unittest test_lifecycle test_phase3 test_deletion_and_answers test_service_and_consumer

# محتاجين Neo4j أو RabbitMQ محلي
$env:NEO4J_INTEGRATION="1"; python -m unittest -v test_neo4j_integration
$env:RABBITMQ_INTEGRATION="1"; $env:AI_DECLARE_TOPOLOGY="1"; python -m unittest test_service_and_consumer
```

`verify_graph.py` و`evaluate_graphrag.py` محتاجين export محلي في `all_tickets/`، وهو مش في الـ repo لأنه فيه أسماء وإيميلات حقيقية.
