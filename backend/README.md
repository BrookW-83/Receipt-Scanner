# Receipt Scanner Backend

Django/DRF backend scaffold for a standalone receipt scanner module.

## Design Targets

- Similar project structure to existing backend
- JWT-ready API surface for mobile integration
- Placeholder processing pipeline for future OCR/AI implementation

## Quick Start

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python manage.py migrate
python manage.py runserver 0.0.0.0:8010
```
