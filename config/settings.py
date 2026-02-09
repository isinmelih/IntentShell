import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class Settings:
    GROQ_API_KEY = os.getenv("GROQ_API_KEY")
    MODEL_NAME = "llama-3.3-70b-versatile" # Updated to current supported model on Groq
    
    # Security Features
    ENABLE_GHOST_MODE = False # GhostDriver (Kernel Access) disabled by default for safety
    
settings = Settings()
