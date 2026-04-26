#!/usr/bin/env python3
"""
Letta Skill - SDK wrapper
Simple CLI for Letta operations using the official letta-client SDK.
"""

import os
import sys
import json
from pathlib import Path

# Add skill lib to path
SKILL_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(SKILL_DIR / "lib"))

from letta_client import Letta

def load_env():
    """Load .env configuration"""
    from dotenv import load_dotenv
    load_dotenv(SKILL_DIR / ".env")

def get_client():
    """Create authenticated Letta client"""
    load_env()
    return Letta(
        api_key=os.getenv("LETTA_API_KEY"),
        base_url=os.getenv("LETTA_BASE_URL", "http://localhost:8283")
    )
