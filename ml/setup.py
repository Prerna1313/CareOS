from setuptools import find_packages, setup


setup(
    name="careos-fall-model",
    version="0.1.0",
    description="Custom Vertex training package for the CareOS fall video model.",
    package_dir={"": "."},
    packages=find_packages(where="."),
    install_requires=[
        "google-cloud-storage>=2.16.0",
        "pandas>=2.2.2",
        "torch>=2.2.0",
        "torchvision>=0.17.0",
    ],
)
