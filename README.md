# 🌱 Plant Inventory App

> *A personal project born from two passions — learning AWS and loving the garden.*

## About

Plant Inventory App is a **serverless AWS application** built to support gardeners in managing their plant care calendar. The app generates a full-year care plan for each plant in the user's garden, then automatically verifies and adjusts the plan monthly based on real weather conditions — sending email notifications with proposed updates.

This project was created as a hands-on learning experience in building and evolving a serverless AWS environment using **Terraform as IaC** and **GitHub Actions as a CI/CD pipeline**.

---

## Architecture

```
User (API Request)
        ↓
   API Gateway
        ↓
┌───────────────────────────────────────────┐
│              AWS Lambda Functions          │
│                                           │
│  translatePlantName  → Anthropic (Claude) │
│  fetchPlantData      → Perenual API       │
│  addUser             → DynamoDB           │
│  generateGardenPlan  → Claude + DynamoDB  │
│  verifyAndUpdateTasks→ Claude + Weather   │
└───────────────────────────────────────────┘
        ↓                    ↓
   DynamoDB              SNS (Email)
        ↓
  EventBridge Scheduler
  (15th of every month)
```

### DynamoDB Tables

| Table | Purpose |
|-------|---------|
| `plants` | Plant species cache from Perenual API |
| `users` | User profiles (location, language, email) |
| `user_inventory` | Plants owned by each user |
| `garden_tasks` | Generated care tasks per plant per user |

---

## Features

- 🌍 **Multilingual support** — task descriptions generated in user's preferred language
- 🌤️ **Weather-aware planning** — monthly task verification based on OpenWeatherMap forecast
- 🤖 **AI-powered** — Claude (Anthropic) generates and verifies garden care plans
- 📧 **Email notifications** — SNS sends monthly proposals to users
- 📅 **Automated scheduling** — EventBridge triggers verification on the 15th of each month
- 🔒 **Secure secrets management** — all API keys stored in AWS SSM Parameter Store

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/users` | Create user profile |
| `POST` | `/translate` | Translate plant name to English |
| `POST` | `/plants` | Fetch and cache plant data |
| `POST` | `/generate-plan` | Generate full-year care plan |

---

## Tech Stack

| Category | Technology |
|----------|-----------|
| Cloud | AWS (Lambda, DynamoDB, API Gateway, SNS, EventBridge, SSM) |
| IaC | Terraform |
| CI/CD | GitHub Actions + OIDC |
| Language | Python 3.12 |
| AI | Anthropic Claude (Haiku) |
| External APIs | Perenual API, OpenWeatherMap |

---

## Infrastructure as Code

All infrastructure is managed with Terraform:

```
terraform/
├── main.tf          # All AWS resources
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── terraform.tfvars # Variable values (gitignored)
└── backend.tf       # Remote state config (gitignored)
```

Remote state is stored in S3 with DynamoDB state locking.

---

## CI/CD Pipeline

Every push to `main` triggers GitHub Actions:

```
git push → checkout → configure AWS (OIDC) → pip install → terraform apply
```

No AWS access keys stored in GitHub — authentication via **OIDC** only.

---

## Lambda Functions

```
lambdas/
├── add_user/              # Save user profile to DynamoDB
├── translate_plant_name/  # Translate plant name via Claude API
├── fetch_plant_data/      # Fetch plant data from Perenual API
├── generate_garden_plan/  # Generate full-year care plan via Claude
└── verify_update_tasks/   # Monthly weather-based plan verification
```

---

## Security

- API keys stored in **AWS SSM Parameter Store** (SecureString)
- GitHub Actions uses **OIDC** — no long-lived credentials
- IAM roles follow **least privilege** principle
- No secrets in code or version control

---

## Future Roadmap

- [ ] Frontend (S3 + CloudFront)
- [ ] User inventory management (add/remove plants)
- [ ] SNS accept/reject flow — users approve proposed task changes via email
- [ ] SQS integration for scalable multi-user processing
- [ ] Lambda Versions for zero-downtime deployments

---

## Author

**Jolanta Kowalewska**  
[LinkedIn](https://www.linkedin.com/in/jolanta-kowalewska-b1281799/) | [GitHub](https://github.com/jolanta-kowalewska)

*AWS Certified Solutions Architect Associate (SAA-C03) — April 2026*
