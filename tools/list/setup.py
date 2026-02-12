try:
    from setuptools import setup
except:
    from distutils.core import setup

setup(
    name='list',
    version='1.2.0',
    author='Steve Losh (original), Workwarrior (adapted)',
    author_email='steve@stevelosh.com',
    url='https://github.com/sjl/t',
    py_modules=['list'],
    entry_points={
        'console_scripts': [
            'list = list:_main',
        ],
    },
)
