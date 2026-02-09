
import sys
import site
print("Sys Path:")
for p in sys.path:
    print(p)

print("\nUser Site:")
print(site.getusersitepackages())

try:
    import pydantic
    print("\nPydantic imported successfully")
    print(pydantic.__file__)
except ImportError as e:
    print(f"\nImportError: {e}")
