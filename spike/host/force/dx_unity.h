// The firmware builds dsp/ as a CMake unity build, so dsp/dx/env.cpp gets `min` from an earlier file in its batch.
#pragma once
#include <algorithm>
using std::min;
