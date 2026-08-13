/*
 * Some Tuya iOS binary objects reference the LLVM profile runtime marker even
 * when the consuming Xcode target is not built with coverage instrumentation.
 * Defining the marker here lets the linker resolve those vendor objects.
 */
int __llvm_profile_runtime = 0;
