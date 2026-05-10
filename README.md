# 🌱 Plant Inventory App

> *A personal project born from two passions — learning AWS and loving the garden.*

**🔗 Live Demo:** https://d1izq5f0ackn63.cloudfront.net

## About

Plant Inventory App is a **serverless AWS application** built to support gardeners in managing their plant care calendar. The app generates a full-year care plan for each plant in the user's garden, then automatically verifies and adjusts the plan monthly based on real weather conditions — sending email notifications with proposed updates.

This project was created as a hands-on learning experience in building and evolving a serverless AWS environment using **Terraform as IaC** (with Workspaces) and **GitHub Actions as a CI/CD pipeline**.

---

## Architecture

```
User Browser
    ↓
CloudFront (HTTPS) ← S3 (static frontend)
    ↓
API Gateway (REST + CORS)
    ↓
┌─────────────────────────────────────────────────────────┐
│                  AWS Lambda Functions                    │
│                                                          │
│  suggestPlants       → DynamoDB (GSI by genus_name)     │
│  startInventoryFlow  → Step Functions trigger           │
│  addToInventory      → DynamoDB                         │
│  getInventory        → DynamoDB                         │
│  deleteFromInventory → DynamoDB (cascade tasks)         │
│  getTasks            → DynamoDB                         │
│  updateTask          → DynamoDB                         │
│  generateGardenPlan  → Anthropic Claude                 │
│  verifyAndUpdateTasks→ Claude + OpenWeatherMap          │
│  addUser             → DynamoDB                         │
│  translatePlantName  → Anthropic Claude                 │
└─────────────────────────────────────────────────────────┘
    ↓                              ↓
Step Functions                 SES (HTML emails)
(parallel: save + plan)            ↑
    ↓                          EventBridge Scheduler
DynamoDB                       (15th of every month)
```

### DynamoDB Tables

| Table | Hash Key | Range Key | Purpose |
|-------|----------|-----------|---------|
| `plants` | species_id | — | ~1800 plant species from Wikidata, GSI on `genus_name` |
| `users` | user_id (email) | — | User profiles (location, language, name) |
| `user_inventory` | user_id | species_id | Plants owned by each user |
| `garden_tasks` | user_id | task_id | Generated care tasks per plant |

---

## Features

- 🌿 **Plant species browser** — searchable database of ~1800 species (Wikidata import)
- 🌍 **Multilingual support** — Polish UI with Polish plant names (Claude translations)
- 🌤️ **Weather-aware planning** — monthly task verification using OpenWeatherMap
- 🤖 **AI-powered** — Claude (Anthropic) generates yearly garden plans and verifies them
- 📧 **Email notifications** — SES sends HTML email proposals on the 15th of every month
- 🗓️ **Yearly timeline view** — visualize all tasks across 12 months with plant filtering
- ✅ **Task management** — mark tasks as done with checkbox
- 🗑️ **Cascade delete** — removing a plant also removes all its tasks (batch_writer)
- 🔒 **Secure secrets management** — all API keys stored in AWS SSM Parameter Store

---

## API Endpoints

| Method | Endpoint | Lambda | Description |
|--------|----------|--------|-------------|
| `POST` | `/users` | addUser | Create user profile |
| `POST` | `/suggest` | suggestPlants | Get plant species by genus name |
| `POST` | `/inventory` | startInventoryFlow | Add plant (triggers Step Functions) |
| `GET` | `/inventory` | getInventory | List user's plants |
| `DELETE` | `/inventory` | deleteFromInventory | Remove plant + cascade tasks |
| `GET` | `/tasks` | getTasks | List user's tasks |
| `PATCH` | `/tasks` | updateTask | Update task status |
| `POST` | `/translate` | translatePlantName | Translate plant name to English |
| `POST` | `/generate-plan` | generateGardenPlan | Generate full-year care plan |

---

## Step Functions Workflow

When a user adds a plant, a Step Functions execution runs in parallel:

```
START
  input: {user_id, plant_name, species_id, scientific_name, plant_name_pl}
        ↓
  ┌──── Parallel ────┐
  ↓                   ↓
addToInventory   generateGardenPlan
(DynamoDB)       (Claude → DynamoDB)
  ↓                   ↓
  └──── END ──────────┘
```

---

## Tech Stack

| Category | Technology |
|----------|-----------|
| Cloud | AWS (Lambda, DynamoDB, API Gateway, Step Functions, EventBridge, SES, SSM, CloudFront, S3) |
| IaC | Terraform v1.14 + Workspaces (dev) |
| CI/CD | GitHub Actions + OIDC (no AWS keys) |
| Language | Python 3.12 |
| Frontend | HTML/CSS/JS (vanilla, hosted on S3 + CloudFront) |
| AI | Anthropic Claude Haiku (claude-haiku-4-5) |
| External APIs | OpenWeatherMap, Wikidata SPARQL |

---

## Infrastructure as Code

All infrastructure is managed with Terraform with workspace support for multi-environment:

```
terraform/
├── main.tf          # All AWS resources
├── cors.tf          # CORS configuration for API Gateway
├── variables.tf     # Input variables
├── outputs.tf       # Output values
└── terraform.tfvars # Variable values (gitignored)
```

**State management:**
- Remote state in S3 with DynamoDB state locking
- Workspaces enable multi-environment setup (dev/staging/prod)
- Path: `s3://bucket/env:/dev/plant-inventory-app/terraform.tfstate`

---

## CI/CD Pipeline

Every push to `main` triggers GitHub Actions:

```
checkout → configure AWS (OIDC) → pip install → 
terraform init → terraform workspace select dev → 
terraform apply → S3 sync frontend → CloudFront invalidation
```

**Security:**
- No AWS access keys stored in GitHub — authentication via **OIDC** only
- API keys in **SSM Parameter Store** (SecureString)
- IAM roles follow **least privilege** principle

---

## Lambda Functions

```
lambdas/
├── add_user/              # Save user profile to DynamoDB
├── suggest_plants/        # Query plants by genus_name (GSI)
├── translate_plant_name/  # Translate plant name via Claude API
├── start_inventory_flow/  # Trigger Step Functions execution
├── add_to_inventory/      # Save plant to user_inventory
├── get_inventory/         # List user's plants
├── delete_from_inventory/ # Remove plant + cascade delete tasks
├── get_tasks/             # List user's tasks
├── update_task/           # Update task status
├── generate_garden_plan/  # Generate yearly plan via Claude
└── verify_update_tasks/   # Monthly weather-based verification
```

---

## Plant Database

The `plants` table is populated by a one-time import from **Wikidata SPARQL API**, then enriched by Claude:

```
scripts/
├── import_plants.py       # Pull plant data from Wikidata
├── enrich_plants.py       # Fill preferred_place, watering, plant_name_pl
└── delete_non_plants.py   # Cleanup utility
```

**Genera covered (~24):** rose, tulip, magnolia, hydrangea, lavender, peony, dahlia, daylily, iris, begonia, lilac, rhododendron, catalpa, juniper, strawberry, barberry, thuja, petunia, hibiscus, raspberry, hosta, geranium, miscanthus, dogwood.

---

## Known Limitations

- Wikidata covers species but rarely cultivars (e.g., "Rosa rugosa" yes, "Rosa 'Augusta Luise'" no)
- SES runs in **sandbox mode** — emails only delivered to verified addresses
- No authentication — `user_id` is hardcoded for demo (would use Cognito in production)
- ~1800 plants — production version would benefit from a paid horticulture API

---

## Future Roadmap

- [ ] Cognito authentication for proper user management
- [ ] Generate PDF — yearly plan export
- [ ] Plant request — let users submit missing species
- [ ] Mobile responsiveness improvements
- [ ] SES production mode + accept/reject flow for monthly emails
- [ ] Staging environment via Terraform Workspace

---

## Author

**Jolanta Kowalewska**  
[LinkedIn](https://www.linkedin.com/in/jolanta-kowalewska-b1281799/) | [GitHub](https://github.com/jolanta-kowalewska)

*AWS Certified Solutions Architect Associate (SAA-C03) — April 2026*
