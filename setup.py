from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext

sourcefiles = ['http11.pyx', 'http11_parser.c']

setup(
    name='http11',
    version='0.1',
    author='Tom',
    author_email='tehunger@gmail.com',
    packages=[
        'http11_server',
    ],
    cmdclass = {'build_ext': build_ext},
    ext_modules = [Extension("http11", sourcefiles, extra_compile_args=["-g"])],
)
