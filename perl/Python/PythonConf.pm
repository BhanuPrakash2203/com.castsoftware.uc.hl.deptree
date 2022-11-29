package Python::PythonConf;

use strict;
use warnings;

our %BUILTIN_EXCEPTION_NAME = (
	BaseException => 1, SystemExit => 1, KeyboardInterrupt => 1, GeneratorExit => 1, Exception => 1, StopIteration => 1, StandardError => 1, BufferError => 1,
	ArithmeticError => 1, FloatingPointError => 1, OverflowError => 1, ZeroDivisionError => 1, AssertionError => 1, AttributeError => 1, EnvironmentError => 1,
	IOError => 1, OSError => 1, WindowsError => 1, VMSError => 1, EOFError => 1, ImportError => 1, LookupError => 1, IndexError => 1, KeyError => 1,
	MemoryError => 1, NameError => 1, UnboundLocalError => 1, ReferenceError => 1, RuntimeError => 1, NotImplementedError => 1, SyntaxError => 1,
	IndentationError => 1, TabError => 1, SystemError => 1, TypeError => 1, ValueError => 1, UnicodeError => 1, UnicodeDecodeError => 1, UnicodeEncodeError => 1,
	UnicodeTranslateError => 1
);

our %DEDICATED_ALIASES = (
	'numpy' => 'np',
	'scipy' => 'sp',
	'pandas' => 'pd',
	'matplotlib' => 'mpl',
	'matplotlib.pyplot' => 'plt',
	'seaborn' => 'sns',
	'datetime' => 'dt',
);

1;


