/******************************************************************************\
* GTK-NoCSD                                                                    *
* Copyright (C) 2025-2026 MorsMortium                                          *
* This program is free software: you can redistribute it and/or modify         *
* it under the terms of the GNU General Public License as published by         *
* the Free Software Foundation, either version 3 of the License, or            *
* (at your option) any later version.                                          *
*                                                                              *
* This program is distributed in the hope that it will be useful,              *
* but WITHOUT ANY WARRANTY; without even the implied warranty of               *
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                *
* GNU General Public License for more details.                                 *
*                                                                              *
* You should have received a copy of the GNU General Public License            *
* along with this program.  If not, see <http://www.gnu.org/licenses/>.        *
\******************************************************************************/

#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <libadwaita-1/adwaita.h>
#include <link.h>
#include <sys/stat.h>

// List of arguments, full binary and number of them is saved for GTK
// applications, in case of crash, to restart them without the library
char **GTKNoCSDArguments = NULL, *GTKNoCSDBinary = NULL;
size_t GTKNoCSDArgumentNumber = 0;

void GTKNoCSDSaveArguments(void) {
	// Save the arguments into a variable

	// Open file, return on failure
	int File = open("/proc/self/cmdline", O_RDONLY);
	if (File < 0) {
		return;
	}

	// Read file, close it, return on failure
	char Buffer[8192];
	ssize_t Length = read(File, Buffer, sizeof(Buffer) - 1);
	close(File);
	if (Length <= 0) {
		return;
	}
	Buffer[Length] = '\0';

	// Count arguments
	size_t Number = 0;
	for (ssize_t Index = 0; Index < Length; Index++) {
		if (Buffer[Index] == '\0') {
			Number++;
		}
	}

	// Allocate memory for array of arguments, return on failure
	GTKNoCSDArguments = calloc(Number + 1, sizeof(char *));
	if (GTKNoCSDArguments == NULL) {
		return;
	}

	// Copy each line into the array, close it, return on failue
	char *Line = Buffer;
	for (size_t Index = 0; Index < Number; Index++) {
		GTKNoCSDArguments[Index] = strdup(Line);

		// Clean up on failure
		if (GTKNoCSDArguments[Index] == NULL) {
			while (Index--) {
				free(GTKNoCSDArguments[Index]);
			}
			free(GTKNoCSDArguments);
			GTKNoCSDArguments = NULL;
			return;
		}
		Line += strlen(Line) + 1;
	}
	GTKNoCSDArguments[Number] = NULL;
	GTKNoCSDArgumentNumber = Number;

	// Save binary with full path
	Length = readlink("/proc/self/exe", Buffer, sizeof(Buffer) - 1);
	if (0 < Length) {
		Buffer[Length] = '\0';
		GTKNoCSDBinary = strdup(Buffer);
	}
}

// Copies for the crash handler to use, since it loses the originals
#define TO_CHILD_COPY 3
#define TO_PARENT_COPY 4
#define TO_CHILD_END_COPY 5

// Anonymous pipe data for multi process communication, in both directions
int GTKNoCSDPipeToChild[2], GTKNoCSDPipeToParent[2], GTKNoCSDPipeToChildEnd[2];

// Original actions for signals, set up by the application
struct sigaction GTKNoCSDSEGVAction;
struct sigaction GTKNoCSDABRTAction;
struct sigaction GTKNoCSDFPEAction;
struct sigaction GTKNoCSDILLAction;
struct sigaction GTKNoCSDBUSAction;

void GTKNoCSDAction(int Signal, siginfo_t *Info, void *UContext) {
	// Send message to the crash loop about caught signals and run the original
	// handlers to keep applications running, in case of not fatal signal

	// Send a message to the other process that a signal has been caught
	G_GNUC_UNUSED ssize_t Ignore = write(GTKNoCSDPipeToChild[1], "1", 1);

	// Get the correct original action
	struct sigaction Action;
	if (Signal == SIGSEGV) {
		Action = GTKNoCSDSEGVAction;
	} else if (Signal == SIGABRT) {
		Action = GTKNoCSDABRTAction;
	} else if (Signal == SIGFPE) {
		Action = GTKNoCSDFPEAction;
	} else if (Signal == SIGILL) {
		Action = GTKNoCSDILLAction;
	} else if (Signal == SIGBUS) {
		Action = GTKNoCSDBUSAction;
	}

	// Run the original action
	if (Action.sa_flags & SA_SIGINFO && Action.sa_sigaction != NULL) {
		Action.sa_sigaction(Signal, Info, UContext);
	} else if (Action.sa_handler == SIG_DFL) {
		sigaction(Signal, &Action, NULL);
		raise(Signal);
	} else if (Action.sa_handler != SIG_IGN) {
		Action.sa_handler(Signal);
	}
}

// Pid of crash handler process, 5 different possible values:
// -3: Have not tried yet | -2: Failed before trying | -1: Failed forking
// 0: In child process | 0<: In parent process
pid_t GTKNoCSDCrashPid = -3;

void GTKNoCSDExit(void) {
	// Send a message on successful exits so the application is not restarted
	if (0 < GTKNoCSDCrashPid) {
		G_GNUC_UNUSED ssize_t Ignore = write(GTKNoCSDPipeToChild[1], "0", 1);
	}
}

// Requires stack realignment because bypassing the C runtime startup leaves
// the stack unaligned, violating the System V AMD64 ABI.
#if defined(__i386__) || defined(__x86_64__)
__attribute__((visibility("default"), force_align_arg_pointer))
#else
__attribute__((visibility("default")))
#endif
void GTKNoCSDMain(void) {
	// This runs when the library is started as an executable

	// Musl does not run constructors for custom entry points
	if (GTKNoCSDArguments == NULL) {
		GTKNoCSDSaveArguments();
	}

	// Unset library for next start, in case of crash
	setenv("LD_PRELOAD", "", 1);

	// Send handshake to parent, stop execution of process
	G_GNUC_UNUSED ssize_t Ignore = write(TO_PARENT_COPY, "1", 1);

	// Wait until parent ends
	char Buffer;
	Ignore = read(TO_CHILD_END_COPY, &Buffer, 1);

	// Go through sent signals, 0 means successful exit, others mean a signal
	// was caught
	bool Restart = false;
	while (read(TO_CHILD_COPY, &Buffer, 1) > 0) {
		Restart = true;
		if (Buffer == '0') {
			Restart = false;
			break;
		}
	}

	// Restart if needed, leave
	Dl_info Information;
	if (Restart && GTKNoCSDArguments != NULL && GTKNoCSDArgumentNumber > 0 &&
		dladdr((void *) (uintptr_t) GTKNoCSDMain, &Information) != 0) {
		printf("GTK-NoCSD: Crash detected, restarting without library.\n");

		// Find library, start program after it
		for (size_t Index = 0; Index < GTKNoCSDArgumentNumber ; ++Index ) {
			const char *Library = Information.dli_fname;
			if (strcmp(GTKNoCSDArguments[Index], Library) == 0) {
				execve(GTKNoCSDArguments[Index + 1],
					GTKNoCSDArguments + Index + 1, environ);
			}
		}
	}
	_exit(0);
}

bool GTKNoCSDLibraryInPath(const char *Path) {
	// Check if path contains GTK or Flutter library, for AppImage

	// Dynamic list of paths to visit, initial capacity for less reallocs
	size_t Capacity = 16;
	char **Paths = malloc(Capacity * sizeof(char *));
	if (Paths == NULL) {
		return false;
	}

	// Set initial path
	size_t Count = 0;
	Paths[Count++] = strdup(Path);
	if (Paths[0] == NULL) {
		free(Paths);
		return false;
	}

	// Go through all files
	while (Count > 0) {
		char *CurrentPath = Paths[--Count];

		// Open directory
		DIR *Directory = opendir(CurrentPath);
		if (Directory == NULL) {
			free(CurrentPath);
			continue;
		}

		struct dirent *Entry;
		while ((Entry = readdir(Directory)) != NULL) {
			// Do not recurse into current and outer directories
			if (Entry->d_name[0] == '.' &&
				(Entry->d_name[1] == '\0' ||
				(Entry->d_name[1] == '.' && Entry->d_name[2] == '\0'))) {
				continue;
			}

			if (Entry->d_type == DT_DIR) {
				// Get full path of file, go to next file on failure
				char *FullPath = malloc(
					strlen(CurrentPath) + strlen(Entry->d_name) + 2);
				if (FullPath == NULL) {
					continue;
				}
				sprintf(FullPath, "%s/%s", CurrentPath, Entry->d_name);

				// Add subdirectory to list
				if (Count == Capacity) {
					Capacity *= 2;
					char **Temporary = realloc(Paths,
							Capacity * sizeof(char *));
					if (Temporary == NULL) {
						free(FullPath);
						continue;
					}
					Paths = Temporary;
				}
				Paths[Count++] = FullPath;
			} else if (Entry->d_type == DT_REG) {
				// Check if the filename is GTK or Flutter library. Flutter uses
				// GTK for windowing while might not have it in the directory
				if ((strncmp(Entry->d_name, "libgtk-", 7) == 0 ||
					strncmp(Entry->d_name, "libflutter", 10) == 0) &&
					strstr(Entry->d_name, ".so") != NULL) {
					// If found, clean up everything and return success
					closedir(Directory);
					free(CurrentPath);
					for (size_t Index = 0; Index < Count; ++Index) {
						free(Paths[Index]);
					}
					free(Paths);
					return true;
				}
			}
		}

		closedir(Directory);
		free(CurrentPath);
	}

	free(Paths);
	return false;
}

void GTKNoCSDUnsetLDPreload(void) {
	// setenv does not always work before execve in these specific contexts,
	// so LD_PRELOAD is stripped manually from the environment array.
	if (environ != NULL) {
		for (char **Variable = environ; *Variable != NULL; ++Variable) {
			if (strncmp(*Variable, "LD_PRELOAD=", 11) == 0) {
				(*Variable)[11] = '\0';
				break;
			}
		}
	}
}

bool GTKNoCSDOnLomiri = false, GTKNoCSDCSD = false, GTKNoCSDCSDPadding = false,
	GTKNoCSDNoCSS = false;
void *(*o_dlsym)(void *, const char *) = NULL;
char *GTKNoCSDLD = NULL, *GTKNoCSDLibC = NULL, *GTKNoCSDTheme = NULL;

void *GTKNoCSDResolvePointer(ElfW(Addr) Base, ElfW(Addr) Pointer) {
	// Musl pointers are offsets from base, so they are added to it
	// GLibC pointers are actual pointers so they are returned as given
	return Pointer >= Base ? (void *) Pointer : (void *) (Base + Pointer);
}

int GTKNoCSDGetDLSym(struct dl_phdr_info *Information,
	G_GNUC_UNUSED size_t Size, G_GNUC_UNUSED void *Data) {
	// Get dlsym for being able to overwrite it for certain language bindings

	// LibC or LD in case of Musl
	if (!Information->dlpi_name || strstr(
			Information->dlpi_name, GTKNoCSDLibC) != Information->dlpi_name) {
		return 0;
	}

	// Shorthand
	ElfW(Addr) Base = Information->dlpi_addr;

	// Get dynamic entries. These contain all library information
	ElfW(Dyn) * Dynamics = NULL;
	for (int Index = 0; Index < Information->dlpi_phnum; ++Index) {
		if (Information->dlpi_phdr[Index].p_type == PT_DYNAMIC) {
			Dynamics = (ElfW(Dyn) *)(Base +
					Information->dlpi_phdr[Index].p_vaddr);
			break;
		}
	}

	// SymTab contains symbols, StrTab contains symbol names. Fetch both
	ElfW(Sym) * SymTab = NULL;
	const char *StrTab = NULL;
	for (ElfW(Dyn) * Dynamic = Dynamics; Dynamic->d_tag != DT_NULL; Dynamic++) {
		if (Dynamic->d_tag == DT_SYMTAB) {
			SymTab = (ElfW(Sym) *)GTKNoCSDResolvePointer(Base,
					Dynamic->d_un.d_ptr);
		} else if (Dynamic->d_tag == DT_STRTAB) {
			StrTab = (const char *) GTKNoCSDResolvePointer(Base,
					Dynamic->d_un.d_ptr);
		}
	}

	// Getting the actual length does not seem to work. This assumes that it
	// will be present. If not, either here or somewhere else will be a crash
	for (size_t Index = 0; Index < 50000; Index++) {
		if (strcmp(StrTab + SymTab[Index].st_name, "dlsym") == 0) {
			o_dlsym = (void *) (Base + SymTab[Index].st_value);
			return 1;
		}
	}

	return 0;
}

int GTKNoCSDGetLDAndLibC(struct dl_phdr_info *Information,
	G_GNUC_UNUSED size_t Size, G_GNUC_UNUSED void *Data) {
	// Get LD and LibC libraries for crash handler and getting dlsym

	if (Information->dlpi_name != NULL) {
		// Used for starting the crash handler. Finds the dynamic linker across
		// GlibC, musl, and Hurd.
		if (GTKNoCSDLD == NULL && strstr(Information->dlpi_name, "/ld-") != NULL
			&& strstr(Information->dlpi_name, ".so.") != NULL) {
			GTKNoCSDLD = strdup(Information->dlpi_name);
		}

		// LibC contains dlsym on GlibC
		if (GTKNoCSDLibC == NULL && strstr(Information->dlpi_name, "/libc.")
			!= NULL && strstr(Information->dlpi_name, ".so.") != NULL) {
			GTKNoCSDLibC = strdup(Information->dlpi_name);
		}

		// If both are found, leave
		if (GTKNoCSDLD != NULL && GTKNoCSDLibC != NULL) {
			return 1;
		}
	}

	return 0;
}

void GTKNoCSDInitDLSym(bool Unload) {
	// Fully get dlsym, exit on failure or force unload

	// Get dlsym
	if (o_dlsym == NULL && !Unload) {
		dl_iterate_phdr(GTKNoCSDGetLDAndLibC, NULL);
		GTKNoCSDLibC = GTKNoCSDLibC == NULL ? GTKNoCSDLD : GTKNoCSDLibC;
		dl_iterate_phdr(GTKNoCSDGetDLSym, NULL);
	}

	// If still not found, unload instead of crash
	if (o_dlsym == NULL || Unload) {
		if (GTKNoCSDArguments == NULL) {
			GTKNoCSDSaveArguments();
		}
		if (GTKNoCSDArguments != NULL) {
			GTKNoCSDUnsetLDPreload();
			execve(GTKNoCSDBinary != NULL ? GTKNoCSDBinary :
				GTKNoCSDArguments[0], GTKNoCSDArguments, environ);
			_exit(0);
		}
	}
}

__attribute__((constructor))
static void GTKNoCSDInit(void) {
	// This runs both when preloaded and when started as executable

	GTKNoCSDInitDLSym(false);

	// Save arguments. When preloaded, this is the started programs arguments,
	// sent into the library as executable, where it is saved again, for restart
	GTKNoCSDSaveArguments();

	// If already checked appimage, then no longer check it and unload if needed
	// GTK_CSD=1 disables the library
	char *AppImage = getenv("GTK-NoCSDAppImage");
	const char *CSD = getenv("GTK_CSD");
	bool Disable = CSD != NULL && CSD[0] == '1';

	// AppImages might use GLib functions while not being GTK applications and
	// not supplying the needed functions. They are dealt with here
	for (size_t Index = 0; !Disable && AppImage == NULL &&
		Index < GTKNoCSDArgumentNumber; ++Index) {
		// Go through all arguments

		// If argument ends with AppRun or starts with /tmp/.mount_, it most
		// likely is an AppImage
		char *Argument = GTKNoCSDArguments[Index];
		const char *AppRun = strstr(Argument, "AppRun");
		char *(*Find)(const char *, int) = NULL;
		if (AppRun != NULL && strlen(AppRun) == 6) {
			Find = strrchr;
		} else if (strstr(Argument, "/tmp/.mount_") == Argument) {
			Find = strchr;
		}

		// Duplicate argument, find last or next slash
		if (Find != NULL) {
			char *Path = strdup(Argument);
			if (Path != NULL) {
				char *Last = Find(Path + (Find == strchr ? 12 : 0), '/');

				// Cut off everything after slash, check if directory has GTK
				if (Last != NULL) {
					*Last = '\0';
					Disable = !GTKNoCSDLibraryInPath(Path);
				}

				// Only check it once, for speedup, clean up and exit early
				setenv("GTK-NoCSDAppImage", "1", 1);
				free(Path);
				break;
			}
		}
	}

	// Check if the library is loaded into the Cambalache internal app, Merengue
	// This is a development environment and the library is not needed to run
	// Or if loaded into sbuild, a Debian build tool, where it produces spam
	if (GTKNoCSDArguments != NULL && GTKNoCSDArguments[0] != NULL &&
		GTKNoCSDArguments[1] != NULL && !Disable) {
		Disable = strstr(GTKNoCSDArguments[0], "python") != NULL &&
			strstr(GTKNoCSDArguments[1], "/merengue\0") != NULL;
		Disable = Disable || (strstr(GTKNoCSDArguments[0], "perl") != NULL &&
			strstr(GTKNoCSDArguments[1], "/sbuild\0") != NULL);
	}

	// For package level loading disable on everything GNOME except Flashback
	// GTK_NOCSD_GNOME=1 disables this check and enables the library for GNOME
	const char *Desktop = getenv("XDG_CURRENT_DESKTOP");
	const char *GNOME = getenv("GTK_NOCSD_GNOME");
	Disable = Disable || ((GNOME == NULL || GNOME[0] != '1')
		&& (Desktop != NULL && strstr(Desktop, "GNOME") != NULL
		&& strstr(Desktop, "GNOME-Flashback") == NULL));

	// Do not unload from gnome-session
	for (size_t Index = 0; Index < GTKNoCSDArgumentNumber && Disable; ++Index) {
		Disable = Disable && strstr(GTKNoCSDArguments[Index],
				"gnome-session") == NULL;
	}

	// If not needed, unset library, restart
	if (Disable && GTKNoCSDArguments != NULL) {
		GTKNoCSDInitDLSym(true);
	}

	// In Lomiri transient-for changes have to be delayed
	GTKNoCSDOnLomiri = Desktop != NULL && strstr(Desktop, "Lomiri") != NULL;

	// Whether the user wants to retain internal GTK CSD
	const char *NoCSDCSD = getenv("GTK_NOCSD_CSD");
	GTKNoCSDCSD = NoCSDCSD != NULL && NoCSDCSD[0] == '1';

	// Whether the user wants to remove padding from internal GTK CSD
	const char *NoCSDCSDPadding = getenv("GTK_NOCSD_CSD_PADDING");
	GTKNoCSDCSDPadding = NoCSDCSDPadding != NULL && NoCSDCSDPadding[0] == '1';

	// Whether the user wants to disable loading any CSS
	const char *NoCSDNoCSS = getenv("GTK_NOCSD_NO_CSS");
	GTKNoCSDNoCSS = NoCSDNoCSS != NULL && NoCSDNoCSS[0] == '1';

	// Set the GTK_CSD environment variable for applications that recognize it
	setenv("GTK_CSD", "0", 1);

	// Save theme
	GTKNoCSDTheme = getenv("GTK_THEME");
}

// GTypes used for identifying widgets
GType GTKNoCSDGTKWindow = 0;
GType GTKNoCSDADWWindow = 0;
GType GTKNoCSDHDYWindow = 0;
GType GTKNoCSDGTKApplicationWindow = 0;
GType GTKNoCSDADWApplicationWindow = 0;
GType GTKNoCSDHDYApplicationWindow = 0;
GType GTKNoCSDGTKHeaderBar = 0;
GType GTKNoCSDADWHeaderBar = 0;
GType GTKNoCSDHDYHeaderBar = 0;
GType GTKNoCSDContainer = 0;
GType GTKNoCSDGTKShortcutsWindow = 0;
GType GTKNoCSDGTKBuilder = 0;
GType GTKNoCSDGTKLabel = 0;
GType GTKNoCSDGTKBox = 0;
GType GTKNoCSDGTKSearchBar = 0;
GType GTKNoCSDADWDialog = 0;
GType GTKNoCSDGTKToggleButton = 0;
GType GTKNoCSDGTKImage = 0;
GType GTKNoCSDADWWindowTitle = 0;
GType GTKNoCSDGTKFileChooserDialog = 0;
GType GTKNoCSDGTKFileChooserWidget = 0;
GType GTKNoCSDGTKButton = 0;

// All GTK/GLib functions overwritten or used from GTK3
void (*o_gtk_window_present)(GtkWindow *) = NULL;
void (*o_gtk_widget_set_visible)(GtkWidget *, gboolean) = NULL;
gboolean (*o_gtk_widget_get_visible)(GtkWidget *) = NULL;
GtkWidget * (*o_gtk_window_get_child)(GtkWindow *) = NULL;
void (*o_gtk_window_set_child)(GtkWindow *, GtkWidget *) = NULL;
GtkWidget * (*o_gtk_widget_get_parent)(GtkWidget *) = NULL;
GtkWidget * (*o_gtk_widget_get_first_child)(GtkWidget *) = NULL;
GtkWidget * (*o_gtk_widget_get_last_child)(GtkWidget *) = NULL;
GtkWidget * (*o_gtk_window_get_titlebar)(GtkWindow *) = NULL;
GtkWidget * (*o_gtk_about_dialog_new)(void) = NULL;
void (*o_gtk_window_set_titlebar)(GtkWindow *, GtkWidget *) = NULL;
GType (*o_gtk_window_get_type)(void) = NULL;
GType (*o_gtk_application_window_get_type)(void) = NULL;
GType (*o_gtk_header_bar_get_type)(void) = NULL;
GType (*o_adw_window_get_type)(void) = NULL;
GType (*o_adw_application_window_get_type)(void) = NULL;
GType (*o_gtk_container_get_type)(void) = NULL;
GType (*o_hdy_window_get_type)(void) = NULL;
GType (*o_hdy_application_window_get_type)(void) = NULL;
GType (*o_adw_header_bar_get_type)(void) = NULL;
GType (*o_hdy_header_bar_get_type)(void) = NULL;
GType (*o_gtk_shortcuts_window_get_type)(void) = NULL;
GType (*o_gtk_builder_get_type)(void) = NULL;
GType (*o_gtk_label_get_type)(void) = NULL;
GType (*o_gtk_box_get_type)(void) = NULL;
GType (*o_gtk_widget_get_type)(void) = NULL;
GType (*o_gtk_search_bar_get_type)(void) = NULL;
GType (*o_adw_dialog_get_type)(void) = NULL;
GType (*o_gtk_toggle_button_get_type)(void) = NULL;
GType (*o_gtk_image_get_type)(void) = NULL;
GType (*o_adw_window_title_get_type)(void) = NULL;
GType (*o_gtk_file_chooser_dialog_get_type)(void) = NULL;
GType (*o_gtk_file_chooser_widget_get_type)(void) = NULL;
GType (*o_gtk_button_get_type)(void) = NULL;
gboolean (*o_gtk_css_provider_load_from_data) (GtkCssProvider *, const gchar *,
	gssize, GError **) = NULL;
void (*o_gtk_style_context_add_provider_for_screen) (void *,
	GtkStyleProvider *, guint) = NULL;
void * (*o_gdk_screen_get_default) (void) = NULL;
void * (*o_gtk_widget_get_window) (GtkWidget *) = NULL;
GtkWidget *(*o_gtk_bin_get_child) (void *) = NULL;
void (*o_gtk_box_pack_start) (GtkBox *, GtkWidget *, gboolean, gboolean,
	guint) = NULL;
GList *(*o_gtk_container_get_children) (void *) = NULL;
void (*o_gtk_container_remove) (void *, GtkWidget *) = NULL;
void (*o_gtk_container_add) (void *, GtkWidget *) = NULL;
void (*o_gtk_container_set_border_width) (void *, guint) = NULL;
void (*o_gtk_header_bar_set_custom_title) (GtkHeaderBar *, GtkWidget *) = NULL;
GtkWidget * (*o_gtk_header_bar_get_custom_title) (GtkHeaderBar *) = NULL;
void (*o_gtk_container_check_resize) (void *) = NULL;
GtkWidget *(*o_gtk_widget_get_toplevel) (GtkWidget *) = NULL;
int (*o_gtk_window_get_window_type) (GtkWindow *) = NULL;
void (*o_gtk_widget_show_all) (GtkWidget *) = NULL;
void (*o_gtk_window_begin_move_drag) (GtkWindow *, gint, gint, gint,
	guint32) = NULL;
GtkWidget *(*o_gtk_event_box_new) (void) = NULL;
int (*o_gdk_event_get_event_type) (void *) = NULL;
gboolean (*o_gdk_event_get_button)(const GdkEvent *, guint *) = NULL;
gboolean (*o_gdk_window_show_window_menu) (void *, void *) = NULL;
int (*o_gtk_window_get_type_hint) (GtkWindow *) = NULL;
gboolean (*o_gdk_event_get_root_coords) (const GdkEvent *, gdouble *,
	gdouble *) = NULL;
gboolean (*o_gtk_builder_add_from_string) (GtkBuilder *, const gchar *, gssize,
	GError **) = NULL;
gboolean (*o_g_module_symbol) (GModule *, const gchar *, gpointer *) = NULL;
void (*o_hdy_header_bar_set_decoration_layout) (GtkWidget *,
	const gchar *) = NULL;
GtkWidget *(*o_hdy_header_bar_get_custom_title) (GtkWidget *) = NULL;
void (*o_hdy_header_bar_set_custom_title) (GtkWidget *, GtkWidget *) = NULL;
void (*o_gtk_widget_reparent) (GtkWidget *, GtkWidget *) = NULL;
GtkSettings *(*o_gtk_settings_get_default) (void) = NULL;
GtkCssProvider *(*o_gtk_css_provider_new) (void) = NULL;
const gchar *(*o_gtk_widget_get_name) (GtkWidget *) = NULL;
GtkStyleContext * (*o_gtk_widget_get_style_context) (GtkWidget *) = NULL;
void (*o_gtk_style_context_add_provider) (GtkStyleContext *, GtkStyleProvider *,
	guint) = NULL;
GtkApplication * (*o_gtk_window_get_application) (GtkWindow *) = NULL;
GdkDisplay *(*o_gdk_display_get_default) (void) = NULL;
void (*o_gtk_css_provider_load_from_string) (GtkCssProvider *,
	const char *) = NULL;
void (*o_gtk_style_context_add_provider_for_display) (GdkDisplay *,
	GtkStyleProvider *, guint) = NULL;
GtkBuilder *(*o_gtk_builder_new) (void) = NULL;
const char *(*o_gtk_check_version) (guint, guint, guint) = NULL;
void (*o_gtk_widget_unparent) (GtkWidget *) = NULL;
void (*o_gtk_box_append) (GtkBox *, GtkWidget *) = NULL;
void (*o_gtk_widget_set_vexpand) (GtkWidget *, gboolean) = NULL;
void (*o_gtk_widget_set_hexpand) (GtkWidget *, gboolean) = NULL;
GtkWidget *(*o_gtk_widget_get_ancestor) (GtkWidget *, GType) = NULL;
GtkWidget *(*o_gtk_revealer_new) (void) = NULL;
void (*o_gtk_revealer_set_transition_duration) (GtkRevealer *, guint) = NULL;
void (*o_gtk_widget_set_layout_manager) (GtkWidget *,
	GtkLayoutManager *) = NULL;
GtkWidget *(*o_gtk_box_new) (GtkOrientation, gint) = NULL;
void (*o_gtk_widget_set_name) (GtkWidget *, const gchar *) = NULL;
void (*o_gtk_label_set_label) (GtkLabel *, const char *) = NULL;
void (*o_gtk_window_set_title) (GtkWindow *, const char *) = NULL;
GtkWidget * (*o_gtk_header_bar_get_title_widget) (GtkHeaderBar *) = NULL;
gboolean (*o_gtk_window_get_decorated) (GtkWindow *);
GtkWidget * (*o_adw_header_bar_get_title_widget) (AdwHeaderBar *) = NULL;
void (*o_gtk_header_bar_set_title_widget) (GtkHeaderBar *, GtkWidget *) = NULL;
GtkWidget *(*o_gtk_grid_new) (void) = NULL;
GtkWidget *(*o_gtk_widget_get_next_sibling) (GtkWidget *) = NULL;
GtkShortcutsWindow *(*o_gtk_application_window_get_help_overlay) (
	GtkApplicationWindow *) = NULL;
void (*o_gtk_header_bar_set_decoration_layout) (GtkHeaderBar *,
	const char *) = NULL;
gboolean (*o_gtk_style_context_has_class) (GtkStyleContext *,
	const gchar *) = NULL;
guint32 (*o_gdk_event_get_time) (GdkEvent *) = NULL;
void (*o_gtk_widget_queue_resize) (GtkWidget *) = NULL;
void (*o_gtk_widget_measure) (GtkWidget *, GtkOrientation, int, int *, int *,
	int *, int *) = NULL;
void (*o_gtk_widget_set_child_visible) (GtkWidget *, gboolean) = NULL;
void (*o_gtk_widget_allocate) (GtkWidget *, int, int, int,
	GskTransform *) = NULL;
int (*o_gtk_widget_get_allocated_height) (GtkWidget *) = NULL;
void (*o_gtk_revealer_set_reveal_child) (GtkRevealer *, gboolean) = NULL;
void (*o_gtk_box_remove) (GtkBox *, GtkWidget *) = NULL;
void (*o_gtk_application_set_app_menu) (GtkApplication *, GMenuModel *) = NULL;
const char * (*o_gtk_window_get_title) (GtkWindow *) = NULL;
const char *(*o_gtk_label_get_text) (GtkLabel *) = NULL;
gboolean (*o_gtk_widget_get_mapped) (GtkWidget *) = NULL;
void (*o_gtk_window_set_hide_on_close) (GtkWindow *, gboolean) = NULL;
void (*o_gtk_window_set_modal) (GtkWindow *, gboolean) = NULL;
void (*o_gtk_window_set_transient_for) (GtkWindow *, GtkWindow *) = NULL;
void (*o_gtk_window_set_destroy_with_parent) (GtkWindow *, gboolean) = NULL;
void (*o_gtk_window_set_decorated) (GtkWindow *, gboolean) = NULL;
void (*o_gtk_box_reorder_child) (GtkBox *, GtkWidget *, gint) = NULL;
void (*o_gtk_widget_set_halign) (GtkWidget *, GtkAlign) = NULL;
void (*o_adw_header_bar_set_decoration_layout) (AdwHeaderBar *,
	const char *) = NULL;
void (*o_adw_dialog_present) (AdwDialog *, GtkWidget *) = NULL;
void (*o_adw_dialog_set_content_height) (AdwDialog *, int) = NULL;
void (*o_adw_dialog_set_content_width) (AdwDialog *, int) = NULL;
AdwDialog * (*o_adw_application_window_get_visible_dialog) (
	AdwApplicationWindow *) = NULL;
AdwDialog * (*o_adw_window_get_visible_dialog) (AdwWindow *) = NULL;
GtkWindow * (*o_gtk_window_get_transient_for) (GtkWindow *) = NULL;
int (*o_gtk_widget_get_width) (GtkWidget *) = NULL;
int (*o_gtk_widget_get_height) (GtkWidget *) = NULL;
int (*o_adw_dialog_get_content_width) (AdwDialog *) = NULL;
int (*o_adw_dialog_get_content_height) (AdwDialog *) = NULL;
void (*o_gtk_window_set_resizable) (GtkWindow *, gboolean) = NULL;
void (*o_gdk_window_get_geometry) (void *, gint *, gint *, gint *,
	gint *) = NULL;
void (*o_gdk_window_get_user_data) (void *, gpointer *) = NULL;
void (*o_gdk_window_get_frame_extents) (void *, GdkRectangle *) = NULL;
void (*o_gtk_widget_insert_action_group) (GtkWidget *, const gchar *,
	GActionGroup *) = NULL;
void (*o_adw_header_bar_set_title_widget) (AdwHeaderBar *, GtkWidget *) = NULL;
void (*o_adw_style_manager_set_color_scheme) (AdwStyleManager *,
	AdwColorScheme) = NULL;
AdwStyleManager * (*o_adw_style_manager_get_default) (void) = NULL;
void (*o_gtk_widget_unrealize) (GtkWidget *) = NULL;
GType (*o_g_type_register_static) (GType, const gchar *, const GTypeInfo *,
	GTypeFlags) = NULL;
GType (*o_g_type_register_static_simple) (GType, const gchar *, guint,
	GClassInitFunc, guint, GInstanceInitFunc, GTypeFlags) = NULL;
void (*o_gtk_widget_set_no_show_all) (GtkWidget *, gboolean) = NULL;
void (*o_gtk_grid_attach) (GtkGrid *, GtkWidget *, int, int, int, int) = NULL;
void (*o_hdy_style_manager_set_color_scheme) (AdwStyleManager *,
	AdwColorScheme) = NULL;
AdwStyleManager * (*o_hdy_style_manager_get_default) (void) = NULL;
void (*o_gtk_widget_destroy) (GtkWidget *) = NULL;
void (*o_gtk_container_propagate_draw) (GtkWidget *, GtkWidget *,
	cairo_t *) = NULL;
GType (*o_g_type_from_name) (const gchar *) = NULL;
GObject *(*o_g_object_new_with_properties) (GType, guint, const char **,
	const GValue *) = NULL;
const gchar * (*o_g_type_name) (GType) = NULL;
GObject * (*o_g_object_new_valist) (GType, const gchar *, va_list) = NULL;
gboolean (*o_g_type_is_a) (GType, GType) = NULL;
guint (*o_g_signal_lookup) (const gchar *, GType) = NULL;
GRegex * (*o_g_regex_new) (const gchar *, GRegexCompileFlags, GRegexMatchFlags,
	GError **) = NULL;
gchar * (*o_g_regex_replace) (const GRegex *, const gchar *, gssize, gint,
	const gchar *, GRegexMatchFlags, GError **) = NULL;
gulong (*o_g_signal_add_emission_hook) (guint, GQuark, GSignalEmissionHook,
	gpointer, GDestroyNotify) = NULL;
GTypeInstance * (*o_g_type_check_instance_cast) (GTypeInstance *, GType) = NULL;
gchar * (*o_g_find_program_in_path) (const gchar *) = NULL;
void (*o_g_object_set) (GObject *, const gchar *, ...) = NULL;
void (*o_g_object_get) (GObject *, const gchar *, ...) = NULL;
GObject * (*o_g_object_ref) (GObject *) = NULL;
void (*o_g_object_unref)(GObject *) = NULL;
gpointer (*o_g_malloc0_n) (gsize, gsize) = NULL;
void (*o_g_object_add_weak_pointer) (GObject *, gpointer *) = NULL;
guint (*o_g_timeout_add) (guint, GSourceFunc, gpointer) = NULL;
gulong (*o_g_signal_handler_find) (GObject *, GSignalMatchType, guint, GQuark,
	GClosure *, gpointer, gpointer) = NULL;
gulong (*o_g_signal_connect_data) (void *, const gchar *, GCallback, gpointer,
	GClosureNotify, GConnectFlags) = NULL;
gpointer (*o_g_object_get_data) (GObject *, const gchar *) = NULL;
void (*o_g_object_set_data) (GObject *, const gchar *, gpointer) = NULL;
gboolean (*o_g_once_init_enter) (void *) = NULL;
void (*o_g_once_init_leave) (void *, gsize) = NULL;
const gchar * (*o_g_intern_static_string) (const gchar *) = NULL;
void * (*o_g_type_class_peek_parent) (void *) = NULL;
GTypeClass * (*o_g_type_check_class_cast) (GTypeClass *, GType) = NULL;
void (*o_g_free) (gpointer) = NULL;
GObject * (*o_g_value_get_object) (const GValue *) = NULL;
guint (*o_g_signal_handlers_disconnect_matched) (void *, GSignalMatchType,
	guint, GQuark, GClosure *, gpointer, gpointer) = NULL;
gboolean (*o_g_type_check_instance_is_a) (GTypeInstance *, GType) = NULL;
void (*o_g_log) (const gchar *, GLogLevelFlags, const gchar *, ...) = NULL;
gchar *(*o_g_get_current_dir) (void) = NULL;
void (*o_g_return_if_fail_warning) (const char *, const char *,
	const char *) = NULL;
void (*o_g_propagate_error) (GError **, GError *) = NULL;
gboolean (*o_g_file_get_contents) (const gchar *, gchar **, gsize *,
	GError **) = NULL;
void (*o_g_bytes_unref) (GBytes *) = NULL;
gconstpointer (*o_g_bytes_get_data) (GBytes *, gsize *) = NULL;
GBytes * (*o_g_resources_lookup_data) (const char *, GResourceLookupFlags,
	GError **) = NULL;
guint (*o_g_idle_add) (GSourceFunc, gpointer) = NULL;
void (*o_g_object_set_valist) (GObject *, const gchar *, va_list) = NULL;
GBinding * (*o_g_object_bind_property) (GObject *, const gchar *, GObject *,
	const gchar *, GBindingFlags) = NULL;
void (*o_g_list_free) (GList *) = NULL;
const gchar * (*o_g_get_application_name) (void) = NULL;
void (*o_g_type_class_adjust_private_offset) (gpointer, gint *) = NULL;
gpointer (*o_g_malloc0) (gsize) = NULL;
const gchar * (*o_gtk_header_bar_get_title) (GtkHeaderBar *) = NULL;
void (*o_gtk_widget_set_size_request) (GtkWidget *, gint, gint) = NULL;
void (*o_gtk_file_chooser_set_extra_widget) (GtkFileChooser *,
	GtkWidget *) = NULL;
GtkWidget * (*o_gtk_file_chooser_get_extra_widget) (GtkFileChooser *) = NULL;
void (*o_gtk_grid_remove_column) (GtkGrid *, gint) = NULL;
gboolean (*o_adw_dialog_close) (AdwDialog *) = NULL;
void (*o_adw_dialog_force_close) (AdwDialog *) = NULL;
void (*o_gtk_im_context_set_cursor_location) (GtkIMContext *,
	const GdkRectangle *) = NULL;
void (*o_gtk_im_context_set_client_window) (GtkIMContext *, void *) = NULL;
gboolean (*o_gtk_window_is_active) (GtkWindow *) = NULL;
void (*o_gtk_widget_get_preferred_width) (GtkWidget *, gint *, gint *) = NULL;

// This is needed by an unavoidable GTK macros for type registration
#define gtk_widget_get_type(...) o_gtk_widget_get_type(__VA_ARGS__)
#define g_type_check_instance_cast(...) o_g_type_check_instance_cast( \
			__VA_ARGS__)
#define g_malloc0_n(...) o_g_malloc0_n(__VA_ARGS__)
#define g_signal_connect_data(...) o_g_signal_connect_data(__VA_ARGS__)
#define g_type_name(...) o_g_type_name(__VA_ARGS__)
#define g_intern_static_string(...) o_g_intern_static_string(__VA_ARGS__)
#define g_type_class_peek_parent(...) o_g_type_class_peek_parent(__VA_ARGS__)
#define g_type_check_class_cast(...) o_g_type_check_class_cast(__VA_ARGS__)
#define g_signal_handlers_disconnect_matched( \
			...) o_g_signal_handlers_disconnect_matched(__VA_ARGS__)
#define g_type_check_instance_is_a(...) o_g_type_check_instance_is_a( \
			__VA_ARGS__)
#define g_log(...) o_g_log(__VA_ARGS__)
#define g_return_if_fail_warning(...) o_g_return_if_fail_warning(__VA_ARGS__)
#define g_type_class_adjust_private_offset(	\
			...) o_g_type_class_adjust_private_offset(__VA_ARGS__)
#define g_malloc0(...) o_g_malloc0(__VA_ARGS__)

// Current and in fetch GTK version of application, name of GTK library
int GTKNoCSDGTKVersion = -1, GTKNoCSDNewGTKVersion = -1;
const char *GTKNoCSDNewGTKName = RTLD_NEXT;

// Macro for generating type checking functions
// WARNING: Macro
#define CHECK_TYPE(Function, Type)								 \
		bool Function(GObject * Object) {						 \
			if ((Type) == 0 || Object == NULL) {				 \
				return false;									 \
			}													 \
			return o_g_type_is_a(G_OBJECT_TYPE(Object), (Type)); \
		}

// These are used instead of the GTK_IS functions
CHECK_TYPE(GTKNoCSDGtkWindow, GTKNoCSDGTKWindow)
CHECK_TYPE(GTKNoCSDGtkApplicatonWindow, GTKNoCSDGTKApplicationWindow)
CHECK_TYPE(GTKNoCSDGtkHeaderBar, GTKNoCSDGTKHeaderBar)
CHECK_TYPE(GTKNoCSDGtkContainer, GTKNoCSDContainer)
CHECK_TYPE(GTKNoCSDGtkShortcutsWindow, GTKNoCSDGTKShortcutsWindow)
CHECK_TYPE(GTKNoCSDGtkBuilder, GTKNoCSDGTKBuilder)
CHECK_TYPE(GTKNoCSDGtkLabel, GTKNoCSDGTKLabel)
CHECK_TYPE(GTKNoCSDGtkBox, GTKNoCSDGTKBox)
CHECK_TYPE(GTKNoCSDGtkSearchBar, GTKNoCSDGTKSearchBar)
CHECK_TYPE(GTKNoCSDGtkFileChooserDialog, GTKNoCSDGTKFileChooserDialog)
CHECK_TYPE(GTKNoCSDGtkFileChooserWidget, GTKNoCSDGTKFileChooserWidget)
CHECK_TYPE(GTKNoCSDHdyWindow, GTKNoCSDHDYWindow)
CHECK_TYPE(GTKNoCSDHdyApplicatonWindow, GTKNoCSDHDYApplicationWindow)
CHECK_TYPE(GTKNoCSDHdyHeaderBar, GTKNoCSDHDYHeaderBar)
CHECK_TYPE(GTKNoCSDAdwWindow, GTKNoCSDADWWindow)
CHECK_TYPE(GTKNoCSDAdwApplicatonWindow, GTKNoCSDADWApplicationWindow)
CHECK_TYPE(GTKNoCSDAdwHeaderBar, GTKNoCSDADWHeaderBar)
CHECK_TYPE(GTKNoCSDAdwDialog, GTKNoCSDADWDialog)
CHECK_TYPE(GTKNoCSDAdwWindowTitle, GTKNoCSDADWWindowTitle)

void *GTKNoCSDGetLibrary(const char *Name, bool Fatal) {
	// Load in a library with fatal error reporting

	void *Library = dlopen(Name, RTLD_LAZY);
	if (Library == NULL && Fatal) {
		// This should never happen
		fprintf(stderr, "GTK-NoCSD: Could not load library: %s\n", Name);
		exit(EXIT_FAILURE);
	}

	return Library;
}

// Macro for simplifying type getting
#define GET_TYPE(TYPE, FUNCTION)				   \
		if (TYPE == 0 && o_ ## FUNCTION != NULL) { \
			TYPE = o_ ## FUNCTION();			   \
		}										   \


// Macros for simplifying function getting
#define LOAD_SYMBOL(LIBRARY, NAME)										\
		*(void **) (&o_ ## NAME) = o_dlsym(LIBRARY, #NAME);				\
		if (o_ ## NAME == NULL) {										\
			fprintf(stderr, "GTK-NoCSD: dlsym failed for %s\n", #NAME);	\
		}																\

#define LOAD_SYMBOL2(HANDLE, NAME, USE_GMODULE)							  \
		if (USE_GMODULE) {												  \
			o_g_module_symbol((HANDLE), #NAME, (gpointer *) &o_ ## NAME); \
		} else {														  \
			*(void **) (&o_ ## NAME) = o_dlsym((HANDLE), #NAME);		  \
		}																  \
		if (o_ ## NAME == NULL) {										  \
			fprintf(stderr, "GTK-NoCSD: failed for %s\n", #NAME);		  \
		}																  \

int GTKNoCSDGetLinkedLibraries(struct dl_phdr_info *Information,
	G_GNUC_UNUSED size_t Size, G_GNUC_UNUSED void *Data) {
	// Get which libraries are linked with the application and determine GTK
	// version based on that

	if (Information->dlpi_name != NULL) {
		if (GTKNoCSDNewGTKVersion == -1) {
			if (strstr(Information->dlpi_name, "libgtk-x11-2.0.so.0") != NULL) {
				GTKNoCSDNewGTKVersion = 2;
			} else if (strstr(Information->dlpi_name,
				"libgtk-3.so.0") != NULL) {
				GTKNoCSDNewGTKVersion = 3;
			} else if (strstr(Information->dlpi_name,
				"libgtk-4.so.1") != NULL) {
				GTKNoCSDNewGTKVersion = 4;
			}
		}

		if (GTKNoCSDNewGTKVersion != -1) {
			return 1;
		}
	}

	return 0;
}

// Whether GTypes have been fetched already, whether platform library was found
bool GTKNoCSDGotTypes = false, GTKNoCSDGotPlatform = true;

void GTKNoCSDGetAdwTypes(void) {
	// Get all used LibAdwaita types

	GET_TYPE(GTKNoCSDADWWindow, adw_window_get_type);
	GET_TYPE(GTKNoCSDADWApplicationWindow, adw_application_window_get_type);
	GET_TYPE(GTKNoCSDADWHeaderBar, adw_header_bar_get_type);
	GET_TYPE(GTKNoCSDADWDialog, adw_dialog_get_type);
	GET_TYPE(GTKNoCSDADWWindowTitle, adw_window_title_get_type);
}

void GTKNoCSDGetHdyTypes(void) {
	// Get all used LibHandy types

	GET_TYPE(GTKNoCSDHDYWindow, hdy_window_get_type);
	GET_TYPE(GTKNoCSDHDYApplicationWindow, hdy_application_window_get_type);
	GET_TYPE(GTKNoCSDHDYHeaderBar, hdy_header_bar_get_type);
}

void GTKNoCSDGetAdwSymbols(void *Library, bool GModule) {
	// Get all used LibAdwaita symbols

	LOAD_SYMBOL2(Library, adw_window_get_type, GModule);
	LOAD_SYMBOL2(Library, adw_application_window_get_type, GModule);
	LOAD_SYMBOL2(Library, adw_header_bar_get_type, GModule);
	LOAD_SYMBOL2(Library, adw_header_bar_get_title_widget, GModule);
	LOAD_SYMBOL2(Library, adw_dialog_get_type, GModule);
	LOAD_SYMBOL2(Library, adw_header_bar_set_decoration_layout, GModule);
	LOAD_SYMBOL2(Library, adw_dialog_present, GModule);
	LOAD_SYMBOL2(Library, adw_dialog_set_content_height, GModule);
	LOAD_SYMBOL2(Library, adw_dialog_set_content_width, GModule);
	LOAD_SYMBOL2(Library, adw_window_title_get_type, GModule);
	LOAD_SYMBOL2(Library, adw_application_window_get_visible_dialog, GModule);
	LOAD_SYMBOL2(Library, adw_window_get_visible_dialog, GModule);
	LOAD_SYMBOL2(Library, adw_dialog_get_content_width, GModule);
	LOAD_SYMBOL2(Library, adw_dialog_get_content_height, GModule);
	LOAD_SYMBOL2(Library, adw_header_bar_set_title_widget, GModule);
	LOAD_SYMBOL2(Library, adw_style_manager_get_default, GModule);
	LOAD_SYMBOL2(Library, adw_style_manager_set_color_scheme, GModule);
	LOAD_SYMBOL2(Library, adw_dialog_close, GModule);
	LOAD_SYMBOL2(Library, adw_dialog_force_close, GModule);
}

void GTKNoCSDGetHdySymbols(void *Library, bool GModule) {
	// Get all used LibHandy symbols

	LOAD_SYMBOL2(Library, hdy_window_get_type, GModule);
	LOAD_SYMBOL2(Library, hdy_application_window_get_type, GModule);
	LOAD_SYMBOL2(Library, hdy_header_bar_get_type, GModule);
	LOAD_SYMBOL2(Library, hdy_header_bar_set_decoration_layout, GModule);
	LOAD_SYMBOL2(Library, hdy_header_bar_get_custom_title, GModule);
	LOAD_SYMBOL2(Library, hdy_header_bar_set_custom_title, GModule);
	LOAD_SYMBOL2(Library, hdy_style_manager_get_default, GModule);
	LOAD_SYMBOL2(Library, hdy_style_manager_set_color_scheme, GModule);
}

void GTKNoCSDGetReferences(bool GetTypes) {
	// Fetch each needed function

	GTKNoCSDInitDLSym(false);

	// These functions are always needed
	void *Library = NULL;
	if (o_g_type_register_static == NULL) {
		Library = GTKNoCSDGetLibrary("libgobject-2.0.so.0", true);
		LOAD_SYMBOL(Library, g_type_register_static);
		LOAD_SYMBOL(Library, g_type_register_static_simple);
		LOAD_SYMBOL(Library, g_type_from_name);
		LOAD_SYMBOL(Library, g_object_new_with_properties);
		LOAD_SYMBOL(Library, g_type_name);
		LOAD_SYMBOL(Library, g_object_new_valist);
		LOAD_SYMBOL(Library, g_type_is_a);
		LOAD_SYMBOL(Library, g_signal_lookup);
		LOAD_SYMBOL(Library, g_regex_new);
		LOAD_SYMBOL(Library, g_regex_replace);
		LOAD_SYMBOL(Library, g_signal_add_emission_hook);
		LOAD_SYMBOL(Library, g_type_check_instance_cast);
		LOAD_SYMBOL(Library, g_find_program_in_path);
		LOAD_SYMBOL(Library, g_object_set);
		LOAD_SYMBOL(Library, g_object_get);
		LOAD_SYMBOL(Library, g_object_ref);
		LOAD_SYMBOL(Library, g_object_unref);
		LOAD_SYMBOL(Library, g_malloc0_n);
		LOAD_SYMBOL(Library, g_object_add_weak_pointer);
		LOAD_SYMBOL(Library, g_timeout_add);
		LOAD_SYMBOL(Library, g_signal_handler_find);
		LOAD_SYMBOL(Library, g_signal_connect_data);
		LOAD_SYMBOL(Library, g_object_get_data);
		LOAD_SYMBOL(Library, g_object_set_data);
		LOAD_SYMBOL(Library, g_once_init_enter);
		LOAD_SYMBOL(Library, g_once_init_leave);
		LOAD_SYMBOL(Library, g_intern_static_string);
		LOAD_SYMBOL(Library, g_type_class_peek_parent);
		LOAD_SYMBOL(Library, g_type_check_class_cast);
		LOAD_SYMBOL(Library, g_free);
		LOAD_SYMBOL(Library, g_value_get_object);
		LOAD_SYMBOL(Library, g_signal_handlers_disconnect_matched);
		LOAD_SYMBOL(Library, g_type_check_instance_is_a);
		LOAD_SYMBOL(Library, g_log);
		LOAD_SYMBOL(Library, g_get_current_dir);
		LOAD_SYMBOL(Library, g_return_if_fail_warning);
		LOAD_SYMBOL(Library, g_propagate_error);
		LOAD_SYMBOL(Library, g_file_get_contents);
		LOAD_SYMBOL(Library, g_bytes_unref);
		LOAD_SYMBOL(Library, g_bytes_get_data);
		LOAD_SYMBOL(Library, g_idle_add);
		LOAD_SYMBOL(Library, g_object_set_valist);
		LOAD_SYMBOL(Library, g_object_bind_property);
		LOAD_SYMBOL(Library, g_list_free);
		LOAD_SYMBOL(Library, g_get_application_name);
		LOAD_SYMBOL(Library, g_type_class_adjust_private_offset);
		LOAD_SYMBOL(Library, g_malloc0);
		dlclose(Library);
	}
	if (o_g_module_symbol == NULL) {
		Library = GTKNoCSDGetLibrary("libgmodule-2.0.so.0", true);
		LOAD_SYMBOL(Library, g_module_symbol);
		dlclose(Library);
	}
	if (o_g_resources_lookup_data == NULL) {
		Library = GTKNoCSDGetLibrary("libgio-2.0.so.0", true);
		LOAD_SYMBOL(Library, g_resources_lookup_data);
		dlclose(Library);
	}

	// Default library name and possible library information
	Dl_info Information;

	// Get used GTK version
	*(void **) (&o_gtk_check_version) = o_dlsym(RTLD_DEFAULT,
			"gtk_check_version");
	if (o_gtk_check_version != NULL) {
		if (o_gtk_check_version(2, 0, 0) == NULL) {
			GTKNoCSDNewGTKVersion = 2;
		} else if (o_gtk_check_version(3, 0, 0) == NULL) {
			GTKNoCSDNewGTKVersion = 3;
		} else if (o_gtk_check_version(4, 0, 0) == NULL) {
			GTKNoCSDNewGTKVersion = 4;
		}

		// Try to get library name from location of gtk_check_version
		if ((GTKNoCSDNewGTKName == RTLD_NEXT ||
			GTKNoCSDGTKVersion != GTKNoCSDNewGTKVersion) && dladdr(
				(void *) (uintptr_t) o_gtk_check_version, &Information) != 0) {
			GTKNoCSDNewGTKName = Information.dli_fname;
		}
	}

	// GTK is statically linked. Function pointers will be collected from binary
	if (o_dlsym(RTLD_NEXT, "gtk_init") == NULL && o_dlsym(RTLD_DEFAULT,
		"gtk_init") != NULL) {
		GTKNoCSDNewGTKName = RTLD_DEFAULT;
	}

	// If gtk_check_version is missing, check linked libraries
	if (GTKNoCSDNewGTKVersion == -1) {
		dl_iterate_phdr(GTKNoCSDGetLinkedLibraries, NULL);
	}

	// Get name of used library, if not found from location of gtk_check_version
	if (GTKNoCSDNewGTKName == RTLD_NEXT) {
		if (GTKNoCSDNewGTKVersion == 2) {
			GTKNoCSDNewGTKName = "libgtk-x11-2.0.so.0";
		} else if (GTKNoCSDNewGTKVersion == 3) {
			GTKNoCSDNewGTKName = "libgtk-3.so.0";
		} else if (GTKNoCSDNewGTKVersion == 4) {
			GTKNoCSDNewGTKName = "libgtk-4.so.1";
		}
	}

	// Save for new type getting if needed
	int OldGTKVersion = GTKNoCSDGTKVersion;

	// Only get functions once or when the version changed
	if (GTKNoCSDGTKVersion != GTKNoCSDNewGTKVersion) {
		GTKNoCSDGTKVersion = GTKNoCSDNewGTKVersion;

		// Load in GTK3 functions for passing through hook
		Library = GTKNoCSDGetLibrary(GTKNoCSDNewGTKName, true);

		// In all GTK versions
		LOAD_SYMBOL(Library, gtk_window_present);
		LOAD_SYMBOL(Library, gtk_widget_set_visible);
		LOAD_SYMBOL(Library, gtk_widget_get_parent);
		LOAD_SYMBOL(Library, gtk_about_dialog_new);
		LOAD_SYMBOL(Library, gtk_settings_get_default);
		LOAD_SYMBOL(Library, gtk_window_get_type);
		LOAD_SYMBOL(Library, gtk_builder_add_from_string);
		LOAD_SYMBOL(Library, gdk_display_get_default);
		LOAD_SYMBOL(Library, gtk_builder_new);
		LOAD_SYMBOL(Library, gtk_check_version);
		LOAD_SYMBOL(Library, gtk_builder_get_type);
		LOAD_SYMBOL(Library, gtk_label_get_type);
		LOAD_SYMBOL(Library, gtk_window_set_modal);
		LOAD_SYMBOL(Library, gtk_window_set_transient_for);
		LOAD_SYMBOL(Library, gtk_window_get_transient_for);
		LOAD_SYMBOL(Library, gtk_window_set_destroy_with_parent);
		LOAD_SYMBOL(Library, gtk_box_get_type);
		LOAD_SYMBOL(Library, gtk_widget_get_type);
		LOAD_SYMBOL(Library, gtk_window_set_decorated);
		LOAD_SYMBOL(Library, gtk_window_get_decorated);
		LOAD_SYMBOL(Library, gtk_im_context_set_cursor_location);

		if (GTKNoCSDGTKVersion < 4) {
			// In GTK2 and GTK3

			LOAD_SYMBOL(Library, gdk_screen_get_default);
			LOAD_SYMBOL(Library, gtk_widget_get_window);
			LOAD_SYMBOL(Library, gtk_bin_get_child);
			LOAD_SYMBOL(Library, gtk_box_pack_start);
			LOAD_SYMBOL(Library, gtk_container_get_children);
			LOAD_SYMBOL(Library, gtk_container_remove);
			LOAD_SYMBOL(Library, gtk_container_add);
			LOAD_SYMBOL(Library, gtk_container_set_border_width);
			LOAD_SYMBOL(Library, gtk_container_get_type);
			LOAD_SYMBOL(Library, gtk_container_check_resize);
			LOAD_SYMBOL(Library, gtk_widget_get_toplevel);
			LOAD_SYMBOL(Library, gtk_window_get_window_type);
			LOAD_SYMBOL(Library, gtk_widget_show_all);
			LOAD_SYMBOL(Library, gtk_window_begin_move_drag);
			LOAD_SYMBOL(Library, gtk_event_box_new);
			LOAD_SYMBOL(Library, gtk_window_get_type_hint);
			LOAD_SYMBOL(Library, gdk_event_get_root_coords);
			LOAD_SYMBOL(Library, gtk_widget_reparent);
			LOAD_SYMBOL(Library, gdk_window_get_geometry);
			LOAD_SYMBOL(Library, gdk_window_get_user_data);
			LOAD_SYMBOL(Library, gdk_window_get_frame_extents);
			LOAD_SYMBOL(Library, gtk_file_chooser_set_extra_widget);
			LOAD_SYMBOL(Library, gtk_file_chooser_get_extra_widget);
		}

		if (GTKNoCSDGTKVersion == 3 || GTKNoCSDGTKVersion == 4) {
			// In GTK3 and GTK4

			LOAD_SYMBOL(Library, gtk_window_get_titlebar);
			LOAD_SYMBOL(Library, gtk_window_set_titlebar);
			LOAD_SYMBOL(Library, gtk_application_window_get_type);
			LOAD_SYMBOL(Library, gtk_header_bar_get_type);
			LOAD_SYMBOL(Library, gtk_css_provider_load_from_data);
			LOAD_SYMBOL(Library, gtk_css_provider_new);
			LOAD_SYMBOL(Library, gtk_widget_get_name);
			LOAD_SYMBOL(Library, gtk_widget_get_style_context);
			LOAD_SYMBOL(Library, gtk_style_context_add_provider);
			LOAD_SYMBOL(Library, gtk_window_get_application);
			LOAD_SYMBOL(Library, gtk_widget_unparent);
			LOAD_SYMBOL(Library, gtk_widget_set_vexpand);
			LOAD_SYMBOL(Library, gtk_widget_set_hexpand);
			LOAD_SYMBOL(Library, gtk_widget_get_ancestor);
			LOAD_SYMBOL(Library, gtk_revealer_new);
			LOAD_SYMBOL(Library, gtk_revealer_set_transition_duration);
			LOAD_SYMBOL(Library, gtk_box_new);
			LOAD_SYMBOL(Library, gtk_widget_set_name);
			LOAD_SYMBOL(Library, gtk_label_set_label);
			LOAD_SYMBOL(Library, gtk_window_set_title);
			LOAD_SYMBOL(Library, gtk_shortcuts_window_get_type);
			LOAD_SYMBOL(Library, gtk_grid_new);
			LOAD_SYMBOL(Library, gtk_application_window_get_help_overlay);
			LOAD_SYMBOL(Library, gtk_header_bar_set_decoration_layout);
			LOAD_SYMBOL(Library, gtk_style_context_has_class);
			LOAD_SYMBOL(Library, gdk_event_get_time);
			LOAD_SYMBOL(Library, gtk_widget_queue_resize);
			LOAD_SYMBOL(Library, gtk_widget_set_child_visible);
			LOAD_SYMBOL(Library, gtk_widget_get_allocated_height);
			LOAD_SYMBOL(Library, gtk_revealer_set_reveal_child);
			LOAD_SYMBOL(Library, gtk_window_get_title);
			LOAD_SYMBOL(Library, gtk_label_get_text);
			LOAD_SYMBOL(Library, gtk_widget_get_mapped);
			LOAD_SYMBOL(Library, gtk_widget_insert_action_group);
			LOAD_SYMBOL(Library, gtk_widget_unrealize);
			LOAD_SYMBOL(Library, gtk_grid_attach);
			LOAD_SYMBOL(Library, gtk_file_chooser_dialog_get_type);
			LOAD_SYMBOL(Library, gtk_file_chooser_widget_get_type);
			LOAD_SYMBOL(Library, gtk_widget_get_visible);
			LOAD_SYMBOL(Library, gtk_button_get_type);
		}

		if (GTKNoCSDGTKVersion == 4) {
			// Only in GTK4

			LOAD_SYMBOL(Library, gtk_window_get_child);
			LOAD_SYMBOL(Library, gtk_window_set_child);
			LOAD_SYMBOL(Library, gtk_widget_get_first_child);
			LOAD_SYMBOL(Library, gtk_widget_get_last_child);
			LOAD_SYMBOL(Library, gtk_css_provider_load_from_string);
			LOAD_SYMBOL(Library, gtk_style_context_add_provider_for_display);
			LOAD_SYMBOL(Library, gtk_box_append);
			LOAD_SYMBOL(Library, gtk_widget_set_layout_manager);
			LOAD_SYMBOL(Library, gtk_header_bar_get_title_widget);
			LOAD_SYMBOL(Library, gtk_header_bar_set_title_widget);
			LOAD_SYMBOL(Library, gtk_widget_get_next_sibling);
			LOAD_SYMBOL(Library, gtk_widget_measure);
			LOAD_SYMBOL(Library, gtk_widget_allocate);
			LOAD_SYMBOL(Library, gtk_box_remove);
			LOAD_SYMBOL(Library, gtk_window_set_hide_on_close);
			LOAD_SYMBOL(Library, gtk_widget_get_width);
			LOAD_SYMBOL(Library, gtk_widget_get_height);
			LOAD_SYMBOL(Library, gtk_window_set_resizable);
			dlclose(Library);

			Library = GTKNoCSDGetLibrary("libadwaita-1.so.0", false);
			if (Library == NULL) {
				GTKNoCSDGotPlatform = false;
				printf("GTK-NoCSD: LibAdwaita not found, will try GModule.\n");
			} else {
				// Only in LibAdwaita

				GTKNoCSDGetAdwSymbols(Library, false);
			}
		}

		if (GTKNoCSDGTKVersion == 3) {
			// Only in GTK3

			LOAD_SYMBOL(Library, gtk_style_context_add_provider_for_screen);
			LOAD_SYMBOL(Library, gtk_header_bar_set_custom_title);
			LOAD_SYMBOL(Library, gtk_header_bar_get_custom_title);
			LOAD_SYMBOL(Library, gdk_event_get_event_type);
			LOAD_SYMBOL(Library, gdk_event_get_button);
			LOAD_SYMBOL(Library, gdk_window_show_window_menu);
			LOAD_SYMBOL(Library, gtk_application_set_app_menu);
			LOAD_SYMBOL(Library, gtk_box_reorder_child);
			LOAD_SYMBOL(Library, gtk_search_bar_get_type);
			LOAD_SYMBOL(Library, gtk_widget_set_halign);
			LOAD_SYMBOL(Library, gtk_toggle_button_get_type);
			LOAD_SYMBOL(Library, gtk_image_get_type);
			LOAD_SYMBOL(Library, gtk_widget_set_no_show_all);
			LOAD_SYMBOL(Library, gtk_widget_destroy);
			LOAD_SYMBOL(Library, gtk_container_propagate_draw);
			LOAD_SYMBOL(Library, gtk_header_bar_get_title);
			LOAD_SYMBOL(Library, gtk_widget_set_size_request);
			LOAD_SYMBOL(Library, gtk_grid_remove_column);
			LOAD_SYMBOL(Library, gtk_im_context_set_client_window);
			LOAD_SYMBOL(Library, gtk_window_is_active);
			LOAD_SYMBOL(Library, gtk_widget_get_preferred_width);
			dlclose(Library);

			Library = GTKNoCSDGetLibrary("libhandy-1.so.0", false);
			if (Library == NULL) {
				GTKNoCSDGotPlatform = false;
				printf("GTK-NoCSD: LibHandy not found, will try GModule.\n");
			} else {
				// Only in LibHandy

				GTKNoCSDGetHdySymbols(Library, false);
			}
		}

		if (GTKNoCSDGTKVersion == 2) {
			dlclose(Library);
		}
	}

	// G functions are too early to fetch GTypes, there they are not fetched yet
	if ((GTKNoCSDGotTypes && OldGTKVersion == GTKNoCSDNewGTKVersion) ||
		!GetTypes) {
		return;
	}

	// Better to get these once and then reuse
	GET_TYPE(GTKNoCSDGTKWindow, gtk_window_get_type);
	GET_TYPE(GTKNoCSDGTKApplicationWindow, gtk_application_window_get_type);
	GET_TYPE(GTKNoCSDGTKHeaderBar, gtk_header_bar_get_type);
	GET_TYPE(GTKNoCSDContainer, gtk_container_get_type);
	GET_TYPE(GTKNoCSDGTKShortcutsWindow, gtk_shortcuts_window_get_type);
	GET_TYPE(GTKNoCSDGTKBuilder, gtk_builder_get_type);
	GET_TYPE(GTKNoCSDGTKLabel, gtk_label_get_type);
	GET_TYPE(GTKNoCSDGTKBox, gtk_box_get_type);
	GET_TYPE(GTKNoCSDGTKSearchBar, gtk_search_bar_get_type);
	GET_TYPE(GTKNoCSDGTKToggleButton, gtk_toggle_button_get_type);
	GET_TYPE(GTKNoCSDGTKImage, gtk_image_get_type);
	GET_TYPE(GTKNoCSDGTKFileChooserDialog, gtk_file_chooser_dialog_get_type);
	GET_TYPE(GTKNoCSDGTKFileChooserWidget, gtk_file_chooser_widget_get_type);
	GET_TYPE(GTKNoCSDGTKButton, gtk_button_get_type);
	GTKNoCSDGetAdwTypes();
	GTKNoCSDGetHdyTypes();
	GTKNoCSDGotTypes = true;
}

int GTKNoCSDMagic(GtkWindow *Window, size_t Options);
gboolean GTKNoCSDRecall(gpointer Data) {
	// Presents the window at a later time

	GTKNoCSDMagic((GtkWindow *) Data, 0);

	return FALSE;
}

// WARNING: These malloced lists will live forever. If the app spawns 100
// regular or undecorated CSD windows, these will grow to 101 length, which will
// use a staggering 808 bytes of memory, on 64bit systems. GTKNoCSDWindowList is
// a list of weak references to check that a window has been destroyed
// when using g_idle_add or such. The actual window values might be NULL
GtkWindow ***GTKNoCSDWindowList = NULL, **GTKNoCSDUndecoratedWindowList = NULL;

GtkWidget *GTKNoCSDGetWindow(GtkWidget *Widget) {
	// Get the window of a widget in both GTK3 and GTK4, unified

	if (GTKNoCSDGTKVersion == 3) {
		GtkWidget *Window = o_gtk_widget_get_toplevel(Widget);
		return GTKNoCSDGtkWindow((GObject *) Window) ? Window : NULL;
	} else {
		return o_gtk_widget_get_ancestor(Widget, GTKNoCSDGTKWindow);
	}
}

bool GTKNoCSDHasClass(GtkWidget *Widget, const char *Class) {
	// Check whether a widget has a CSS class

	GtkStyleContext *Style = o_gtk_widget_get_style_context(Widget);
	return o_gtk_style_context_has_class(Style, Class);
}

bool GTKNoCSDGTK3HasVisible(GtkWidget *Container) {
	// Check if a container has any visible widgets

	// Get children, go through them
	GList *Children = o_gtk_container_get_children(Container);
	for (GList *Iter = Children; Iter != NULL; Iter = Iter->next) {
		// Has visible child
		if (o_gtk_widget_get_visible((GtkWidget *) Iter->data)) {
			o_g_list_free(Children);
			return true;
		}
	}

	// Does not have visible child
	o_g_list_free(Children);
	return false;
}

// Overwrite for not checking parent (LibAdwaita dialog first label)
bool GTKNoCSDLabelParentCheck = true;

gboolean GTKNoCSDLabelChange(gpointer Data) {
	// Check title content, and hide it, if it is the same as the window or
	// application title

	// Disconnect signal, this should only run once per change
	// WARNING: Macro
	g_signal_handlers_disconnect_by_func(
		Data, (GCallback *) GTKNoCSDLabelChange, Data);

	// Check if label is part of any kind of headerbar, leave if not
	GtkWidget *Label = (GtkWidget *) Data;
	GtkWidget *Parent = o_gtk_widget_get_ancestor(Label, GTKNoCSDGTKHeaderBar);
	if (Parent == NULL && GTKNoCSDADWHeaderBar != 0) {
		Parent = o_gtk_widget_get_ancestor(Label, GTKNoCSDADWHeaderBar);
	}
	if (Parent == NULL && GTKNoCSDHDYHeaderBar != 0) {
		Parent = o_gtk_widget_get_ancestor(Label, GTKNoCSDHDYHeaderBar);
	}

	// Do not act if not in header (unless LibAdwaita dialogs), or if in button
	if ((Parent == NULL && GTKNoCSDLabelParentCheck) ||
		o_gtk_widget_get_ancestor(Label, GTKNoCSDGTKButton) != NULL) {
		return FALSE;
	}

	// Get label text and window
	const char *Text = o_gtk_label_get_text((GtkLabel *) Label);
	GtkWindow *Window = (GtkWindow *) GTKNoCSDGetWindow(Label);

	// If window has own title, compare with that, if not, it takes application
	// name, compare with that
	const char *Title = Window != NULL ? o_gtk_window_get_title(Window) : NULL;
	Title = Title == NULL ? o_g_get_application_name() : Title;

	// Only show if different and not empty, or if a default decoration
	if (Title != NULL) {
		bool Visible = (strstr(Title, Text) == NULL && Text[0] != '\0') ||
			(Parent != NULL && GTKNoCSDHasClass(Parent, "default-decoration"));
		if (Visible == o_gtk_widget_get_visible(Label)) {
			return FALSE;
		}
		o_gtk_widget_set_visible(Label, Visible);

		// Very specific XFCE scenario, can be loosened if needed
		// Layered checks for least work if not needed
		if (GTKNoCSDGTKVersion == 3) {
			GtkWidget *Box = o_gtk_widget_get_parent(Label);
			if ((!GTKNoCSDGtkBox((GObject *) Box)) ||
				o_gtk_widget_get_parent(Box) != Parent) {
				return FALSE;
			}

			if (GTKNoCSDHasClass(Label, "title") &&
				GTKNoCSDHasClass(Box, "vertical")) {
				// Hide or show Box based on whether it has visible
				// children, do the same with the header
				o_gtk_widget_set_visible(Box, GTKNoCSDGTK3HasVisible(Box));
				o_gtk_widget_set_visible(Parent,
					GTKNoCSDGTK3HasVisible(Parent));
			}
		}
	}
	return FALSE;
}

void GTKNoCSDTitleChanged(GtkLabel *Label, G_GNUC_UNUSED GParamSpec
	*Spec, G_GNUC_UNUSED gpointer Data) {
	// If widget is already in tree, start checking/changing label, otherwise
	// add signal to start when it will be in tree

	if (!o_gtk_widget_get_mapped((GtkWidget *) Label)) {
		// WARNING: Macro
		g_signal_connect(Label, "map", G_CALLBACK(GTKNoCSDLabelChange), Label);
		return;
	}

	GTKNoCSDLabelChange(Label);
}

bool GTKNoCSDCheckGTK4Header(GtkWidget *Widget) {
	// Check if a widget is a header bar and if it is and the title widget is
	// empty, disable showing it, plus signal it back
	// Also hide simple label titles that are just the window title

	// If widget is label, set up monitor for the content
	if (GTKNoCSDGtkLabel((GObject *) Widget) &&
		o_g_signal_handler_find((GObject *) Widget, G_SIGNAL_MATCH_FUNC, 0,
		0, NULL, (GCallback *) GTKNoCSDTitleChanged, NULL) == 0) {
		// WARNING: Macro
		g_signal_connect(Widget, "notify::label",
			G_CALLBACK(GTKNoCSDTitleChanged), NULL);
		GTKNoCSDTitleChanged((GtkLabel *) Widget, NULL, NULL);
	}

	// Force set decoration layouts to empty
	if (GTKNoCSDAdwHeaderBar((GObject *) Widget)) {
		o_adw_header_bar_set_decoration_layout((AdwHeaderBar *) Widget, "");
		return true;
	} else if (GTKNoCSDGtkHeaderBar((GObject *) Widget) &&
		!(GTKNoCSDCSD && GTKNoCSDHasClass(Widget, "default-decoration"))) {
		// GTK4 headers are never looked for so they are never confirmed
		o_gtk_header_bar_set_decoration_layout((GtkHeaderBar *) Widget, "");
	}

	return false;
}

GtkWidget *GTKNoCSDGetGTK4Headers(GtkWidget *Widget, bool GetWidget) {
	// Recursively searches the entire widget tree for multiple GTK4 or
	// LibAdwaita headers and disables all empty titles or gives back the first
	// found one

	// Check current widget
	if (GTKNoCSDCheckGTK4Header(Widget) && GetWidget) {
		return Widget;
	}

	// Only containers can have children
	GtkWidget *Child = o_gtk_widget_get_first_child(Widget);
	while (Child != NULL) {
		// Check children of widget if there are
		GtkWidget *PossiblyHeader = GTKNoCSDGetGTK4Headers(Child, GetWidget);
		if (PossiblyHeader != NULL && GetWidget) {
			return PossiblyHeader;
		}

		Child = o_gtk_widget_get_next_sibling(Child);
	}

	return NULL;
}

gboolean GTKNoCSDSetGTK4Headers(gpointer Data) {
	// GTK callback for GTKNoCSDGetGTK4Headers

	GTKNoCSDGetGTK4Headers((GtkWidget *) Data, false);

	return FALSE;
}

bool GTKNoCSDTest(GtkWidget *Widget) {
	// Simple test if the widget we deal with is our own

	return Widget != NULL &&
		   strcmp(o_gtk_widget_get_name(Widget), "GTKNoCSD") == 0;
}

gboolean GTKNoCSDHandleShortcutsWindow(gpointer Data) {
	// Check if an application window has a shortcuts window and add SSD to it

	// If the window got destroyed in the meantime, return
	GtkWindow **Window = (GtkWindow **) Data;
	if (*Window == NULL) {
		return FALSE;
	}

	GtkShortcutsWindow *Overlay = o_gtk_application_window_get_help_overlay(
		(GtkApplicationWindow *) Window[0]);

	if (Overlay != NULL) {
		GTKNoCSDMagic((GtkWindow *) Overlay, 0);
	}

	return FALSE;
}

static void GTKNoCSDWindowAdded(G_GNUC_UNUSED GtkApplication *Application,
	GtkWindow *Window) {
	// Add SSD to all added windows

	GTKNoCSDMagic(Window, 0);
}

static void GTKNoCSDApplicationChanged(GObject *Window,
	G_GNUC_UNUSED GParamSpec *Spec) {
	// If the window got added to an application, add window monitor function to
	// the application

	GtkApplication *Application =
		o_gtk_window_get_application((GtkWindow *) Window);

	if (Application != NULL && o_g_signal_handler_find((GObject *) Application,
		G_SIGNAL_MATCH_FUNC, 0, 0, NULL, (GCallback *) GTKNoCSDWindowAdded,
		NULL) == 0) {
		// WARNING: Macro
		g_signal_connect(Application, "window-added",
			G_CALLBACK(GTKNoCSDWindowAdded), NULL);
	}
}

static gboolean GTKNoCSDWindowMap(G_GNUC_UNUSED GSignalInvocationHint *Hint,
	G_GNUC_UNUSED guint Number, const GValue *Values,
	G_GNUC_UNUSED gpointer Data) {
	// Add SSD to all mapped windows

	// Only if the value is a window (might be redundant)
	GObject *Window = o_g_value_get_object(&Values[0]);
	if (GTKNoCSDGtkWindow(Window)) {
		GTKNoCSDMagic((GtkWindow *) Window, 2);
	}

	return TRUE;
}

GtkWidget *GTKNoCSDWindowGetChild(GtkWindow *Window) {
	// Get child of window in both GTK3 and GTK4, unified

	if (GTKNoCSDGTKVersion == 3) {
		return o_gtk_bin_get_child(Window);
	} else {
		return o_gtk_window_get_child(Window);
	}
}

void GTKNoCSDWindowSetChild(GtkWindow *Window, GtkWidget *Widget) {
	// Replace child of window in both GTK3 and GTK4, unified

	if (GTKNoCSDGTKVersion == 3) {
		if (Widget == NULL) {
			GtkWidget *Child = o_gtk_bin_get_child(Window);
			if (Child != NULL) {
				o_gtk_container_remove(Window, Child);
			}
		} else {
			o_gtk_container_add(Window, Widget);
		}
	} else {
		o_gtk_window_set_child(Window, Widget);
	}
}

void GTKNoCSDGtkBoxAdd(GtkWidget *Box, GtkWidget *Widget) {
	// Add to box in both GTK3 and GTK4, unified

	if (GTKNoCSDGTKVersion == 3) {
		o_gtk_box_pack_start((GtkBox *) Box, Widget, false, true, 0);
	} else {
		o_gtk_box_append((GtkBox *) Box, Widget);
	}
}

void GTKNoCSDForceInvisible(GtkWidget *Widget, G_GNUC_UNUSED GParamSpec *Spec,
	G_GNUC_UNUSED gpointer Data) {
	// No show all does not always help, if visibility is set manually. It is
	// forced off here

	o_gtk_widget_set_visible(Widget, false);
	if (o_gtk_widget_set_no_show_all != NULL) {
		o_gtk_widget_set_no_show_all(Widget, true);
	}
}

void GTKNoCSDGTK3SetForceInvisible(GtkWidget *Widget) {
	// Add function to force off visibility, call it once for initial set up

	if (!o_g_signal_handler_find((GObject *) Widget, G_SIGNAL_MATCH_FUNC,
		0, 0, NULL, (GCallback *) GTKNoCSDForceInvisible, NULL)) {
		// WARNING: Macro
		g_signal_connect(Widget, "notify::visible",
			G_CALLBACK(GTKNoCSDForceInvisible), NULL);
	}
	GTKNoCSDForceInvisible(Widget, NULL, NULL);
}

void GTKNoCSDGTK3EmptyTitleChanged(GtkWidget *Header,
	G_GNUC_UNUSED GParamSpec *Spec, G_GNUC_UNUSED gpointer Data) {
	// Make the headerbar take as much space as it would naturally

	int Width = -1;
	o_gtk_widget_get_preferred_width(Header, NULL, &Width);
	o_gtk_widget_set_size_request(Header, Width, -1);
}

void GTKNoCSDGTK3SetEmptyTitle(GtkWidget *Header, bool Setup) {
	// Set up empty title with size monitoring for GTK3

	if (!Setup) {
		o_gtk_widget_set_size_request(Header, -1, -1);

		// WARNING: Macro
		g_signal_handlers_disconnect_by_func(Header,
			(GCallback *) GTKNoCSDGTK3EmptyTitleChanged, NULL);
		return;
	}

	// Check size once
	GTKNoCSDGTK3EmptyTitleChanged(Header, NULL, NULL);

	// Recheck each time on title change
	if (!o_g_signal_handler_find((GObject *) Header, G_SIGNAL_MATCH_FUNC,
		0, 0, NULL, (GCallback *) GTKNoCSDGTK3EmptyTitleChanged, NULL)) {
		// WARNING: Macro
		g_signal_connect(Header, "notify::title",
			G_CALLBACK(GTKNoCSDGTK3EmptyTitleChanged), NULL);
	}
}

bool GTKNoCSDGetGTK3Headers(GtkWidget *Container) {
	// Removing extra close buttons added by certain applications

	// Certain applications set this layout for themselves, here it is unset
	// Also remove empty titles
	if (GTKNoCSDGtkHeaderBar((GObject *) Container) && !(GTKNoCSDCSD &&
		GTKNoCSDHasClass(Container, "default-decoration"))) {
		GtkHeaderBar *Header = (GtkHeaderBar *) Container;
		o_gtk_header_bar_set_decoration_layout(Header, "");
		if (o_gtk_header_bar_get_custom_title(Header) == NULL) {
			GTKNoCSDGTK3SetEmptyTitle(Container, true);
		}
	} else if (GTKNoCSDHdyHeaderBar((GObject *) Container)) {
		o_hdy_header_bar_set_decoration_layout(Container, "");
		if (o_hdy_header_bar_get_custom_title(Container) == NULL) {
			GTKNoCSDGTK3SetEmptyTitle(Container, true);
		}
	}

	// If widget is label, set up monitor for the content
	if (GTKNoCSDGtkLabel((GObject *) Container) &&
		o_g_signal_handler_find((GObject *) Container, G_SIGNAL_MATCH_FUNC, 0,
		0, NULL, (GCallback *) GTKNoCSDTitleChanged, NULL) == 0) {
		// WARNING: Macro
		g_signal_connect(Container, "notify::label",
			G_CALLBACK(GTKNoCSDTitleChanged), NULL);
		GTKNoCSDTitleChanged((GtkLabel *) Container, NULL, NULL);
	}

	if (GTKNoCSDHasClass(Container, "titlebutton")) {
		GTKNoCSDGTK3SetForceInvisible(Container);
		return true;
	}

	// If not a container, leave
	if (!GTKNoCSDGtkContainer((GObject *) Container)) {
		return false;
	}

	// Go through all children, count all and removed number of them
	int Amount = 0, Hidden = 0;
	GList *Children = o_gtk_container_get_children(Container);
	for (GList *Iter = Children; Iter != NULL; Iter = Iter->next) {
		GtkWidget *Child = (GtkWidget *) Iter->data;

		// Go through all children of child too
		if (GTKNoCSDGetGTK3Headers(Child)) {
			GTKNoCSDGTK3SetForceInvisible(Child);
			++Hidden;
		} else {
			// If close button, remove
			if (GTKNoCSDHasClass(Child, "titlebutton")) {
				GTKNoCSDGTK3SetForceInvisible(Child);
				++Hidden;
			}
		}

		++Amount;
	}
	o_g_list_free(Children);

	// If all widgets got removed, remove the container too (title button)
	if (Amount == Hidden && Amount != 0) {
		GTKNoCSDGTK3SetForceInvisible(Container);
		return true;
	}

	return false;
}

gboolean GTKNoCSDSetGTK3Headers(gpointer Data) {
	// GTK callback for GTKNoCSDGetGTK3Headers

	GTKNoCSDGetGTK3Headers((GtkWidget *) Data);

	return FALSE;
}

// One time setups
bool GTKNoCSDSettings = false, GTKNoCSDHooked = false, GTKNoCSDLayout = false;

void GTKNoCSDAddTransient(GtkWindow *Window, gpointer Data) {
	// Set transient-for property window

	o_gtk_window_set_transient_for(Window, (GtkWindow *) Data);

	// WARNING: Macro
	g_signal_handlers_disconnect_by_func(Window,
		(GCallback *) GTKNoCSDAddTransient, Data);
}

void GTKNoCSDChangeTransient(GtkWindow *Window, G_GNUC_UNUSED GParamSpec *Spec,
	G_GNUC_UNUSED gpointer Data) {
	// If transient-for property window was set, while the window was not mapped
	// yet, unset it and delay it to after it got mapped

	GtkWindow *Current = o_gtk_window_get_transient_for(Window);
	if (Current != NULL && !o_gtk_widget_get_mapped((GtkWidget *) Window)) {
		o_gtk_window_set_transient_for(Window, NULL);
		o_gtk_widget_unrealize((GtkWidget *) Window);

		// WARNING: Macro
		g_signal_connect(Window, "map",
			G_CALLBACK(GTKNoCSDAddTransient), Current);
	}
}

void GTKNoCSDHooker(void) {
	// Add hook for all mapped windows to get SSD

	if (!GTKNoCSDHooked && GTKNoCSDGTKWindow != 0) {
		unsigned int Hook = o_g_signal_lookup("map", GTKNoCSDGTKWindow);
		if (0 < Hook) {
			o_g_signal_add_emission_hook(Hook, 0, GTKNoCSDWindowMap, NULL,
				NULL);

			// Only add them once
			GTKNoCSDHooked = true;
		}
	}
}

gboolean GTKNoCSDGTK3EventBoxActions(G_GNUC_UNUSED GtkWidget *Widget,
	void *Event, gpointer Data) {
	// Recreate window controls, dragging when menu is dragged, opening window
	// manager menu on right clicking it

	if (o_gdk_event_get_event_type(Event) == 4) {
		// 4 is button press
		unsigned int Button;
		o_gdk_event_get_button(Event, &Button);

		if (Button == 1) {
			// 1 is left button, dragging starts here
			gdouble X, Y;
			o_gdk_event_get_root_coords(Event, &X, &Y);

			// WARNING: Downcast
			o_gtk_window_begin_move_drag((GtkWindow *) Data, 1,
				(gint) X, (gint) Y, o_gdk_event_get_time(Event));
			return TRUE;
		} else if (Button == 3) {
			// 3 is right button, window manager menu opens here
			o_gdk_window_show_window_menu(o_gtk_widget_get_window(Data), Event);
			return TRUE;
		}
	}

	return FALSE;
}

GtkWidget *GTKNoCSDFirstChild(GtkWidget *Parent) {
	// Get the first child in a container in both GTK3 and GTK4, unified

	if (Parent == NULL) {
		return NULL;
	}

	GtkWidget *Child = NULL;
	if (GTKNoCSDGTKVersion == 3) {
		GList *Children = o_gtk_container_get_children(Parent);
		if (Children == NULL) {
			return NULL;
		}
		Child = (GtkWidget *) Children->data;
		o_g_list_free(Children);
	} else {
		return o_gtk_widget_get_first_child(Parent);
	}

	return Child;
}

static gboolean GTKNoCSDGTK3CurrentWindowStyle(gpointer Data) {
	// The CSS might break when it is applied in the map stage of the window.
	// This makes it properly redraw

	// If the window got destroyed in the meantime, return
	GtkWindow **Window = (GtkWindow **) Data;
	if (*Window == NULL) {
		return FALSE;
	}

	o_gtk_widget_queue_resize((GtkWidget *) Window[0]);
	return FALSE;
}

// These are needed for _get_type() and might be missing in older GLib versions
#undef g_once_init_enter_pointer
#undef g_once_init_leave_pointer
#define g_once_init_enter_pointer o_g_once_init_enter
#define g_once_init_leave_pointer(location, result)	\
		o_g_once_init_leave((location), (gsize) (result))

// The max height, with which a header bar is considered empty
const int GTKNoCSDEmptySize = 5;

// Widget used to hide empty header bar on GTK4
// WARNING: Macro
G_DECLARE_FINAL_TYPE(GTKNoCSDBox, GTKNoCSDBox, GTKNoCSD, BOX, GtkBox)
struct _GTKNoCSDBox {
	GtkBox ParentInstance;
};

// WARNING: Macro
G_DEFINE_TYPE(GTKNoCSDBox, GTKNoCSDBox, GTKNoCSDGTKBox)

static void GTKNoCSDBoxMeasure(GtkWidget *Widget, GtkOrientation Orientation,
	int ForSize, int *Minimum, int *Natural, int *MinimumBaseline,
	int *NaturalBaseline) {
	// Report size to GTK

	// Default no size on no child
	if (Minimum != NULL) {
		*Minimum = 0;
	}
	if (Natural != NULL) {
		*Natural = 0;
	}
	if (MinimumBaseline != NULL) {
		*MinimumBaseline = -1;
	}
	if (NaturalBaseline != NULL) {
		*NaturalBaseline = -1;
	}

	// Get child, return if missing
	GtkWidget *Child = o_gtk_widget_get_first_child(Widget);
	if (Child == NULL) {
		return;
	}

	// Get size needed by child
	int MinimumChild, NaturalChild, MinimumBaselineChild, NaturalBaselineChild;
	o_gtk_widget_measure(Child, Orientation, ForSize, &MinimumChild,
		&NaturalChild, &MinimumBaselineChild, &NaturalBaselineChild);

	// If it is less than 6, hide it
	o_gtk_widget_set_child_visible(Widget, GTKNoCSDEmptySize < NaturalChild);

	// If less than 6 and vertical measurement, return
	if (Orientation == GTK_ORIENTATION_VERTICAL &&
		NaturalChild <= GTKNoCSDEmptySize) {
		return;
	}

	// Report actual size
	if (Minimum != NULL) {
		*Minimum = MinimumChild;
	}
	if (Natural != NULL) {
		*Natural = NaturalChild;
	}
	if (MinimumBaseline != NULL) {
		*MinimumBaseline = MinimumBaselineChild;
	}
	if (NaturalBaseline != NULL) {
		*NaturalBaseline = NaturalBaselineChild;
	}
}

static void GTKNoCSDBoxSizeAllocate(GtkWidget *Widget, int Width, int Height,
	int Baseline) {
	// Allocate widget and child if it exists

	// WARNING: Macro
	GTK_WIDGET_CLASS(GTKNoCSDBox_parent_class)->size_allocate(Widget, Width,
		Height, Baseline);
	GtkWidget *Child = o_gtk_widget_get_first_child(Widget);
	if (Child != NULL) {
		o_gtk_widget_allocate(Child, Width, Height, Baseline, NULL);
	}
}

static void GTKNoCSDBox_class_init(GTKNoCSDBoxClass *Klass) {
	// Set up measure and size allocate functions

	// WARNING: Macro
	GtkWidgetClass *WidgetClass = GTK_WIDGET_CLASS(Klass);
	WidgetClass->measure = GTKNoCSDBoxMeasure;
	WidgetClass->size_allocate = GTKNoCSDBoxSizeAllocate;
}

static void GTKNoCSDBox_init(G_GNUC_UNUSED GTKNoCSDBox *Self) {
}

static gboolean GTKNoCSDGTK3Height(gpointer Data) {
	// Hide widget with Revealer if small enough

	// Get height
	GtkWidget *Widget = (GtkWidget *) Data;
	int Height = o_gtk_widget_get_allocated_height(Widget);

	// Get Revealer
	GtkWidget *Revealer = o_gtk_widget_get_parent(Widget);
	Revealer = o_gtk_widget_get_parent(Revealer);

	// Hide or not
	o_gtk_revealer_set_reveal_child((GtkRevealer *) Revealer,
		GTKNoCSDEmptySize < Height);
	return FALSE;
}

static void GTKNoCSDGTK3HeaderSizeAllocate(GtkWidget *Widget,
	G_GNUC_UNUSED GdkRectangle *Allocation, G_GNUC_UNUSED gpointer Data) {
	// Changing visibility in size allocate is bad, so we do it later
	o_g_idle_add(GTKNoCSDGTK3Height, Widget);
}

GtkWidget *GTKNoCSDGTK3FindWidget(void *Container, bool (*Check) (GObject *)) {
	// Find the widget checked by Check in a container (GTK3)

	GList *Children = o_gtk_container_get_children(Container);

	// Go through each child
	for (GList *Iter = Children; Iter != NULL; Iter = Iter->next) {
		GtkWidget *Child = (GtkWidget *) Iter->data;

		// Return if found
		if (Check((GObject *) Child)) {
			o_g_list_free(Children);
			return Child;
		}

		// Recurse into containers
		if (GTKNoCSDGtkContainer((GObject *) Child)) {
			GtkWidget *Found = GTKNoCSDGTK3FindWidget(Child, Check);

			// Return if found
			if (Found != NULL) {
				o_g_list_free(Children);
				return Found;
			}
		}
	}

	// It was not found
	o_g_list_free(Children);
	return NULL;
}

GtkWidget *GTKNoCSDGTK4FindWidget(GtkWidget *Container,
	bool (*Check) (GObject *)) {
	// Find the widget checked by Check in a container (GTK4)

	// Go through each child
	for (GtkWidget *Child = o_gtk_widget_get_first_child(Container);
		Child != NULL; Child = o_gtk_widget_get_next_sibling(Child)) {
		// Return if found
		if (Check((GObject *) Child)) {
			return Child;
		}

		// Recurse into children
		GtkWidget *Found = GTKNoCSDGTK4FindWidget(Child, Check);

		// Return if found
		if (Found != NULL) {
			return Found;
		}
	}

	// It was not found
	return NULL;
}

void GTKNoCSDAddToList(GtkWindow ***List, GtkWindow *Window) {
	// Add a window to a list of windows

	// Create list with single item if first window
	if (*List == NULL) {
		*List = malloc(sizeof(GtkWindow *) * 2);
		(*List)[0] = Window;
		(*List)[1] = NULL;
	} else {
		// Check if window is already added
		size_t Index = 0;
		while ((*List)[Index] != NULL) {
			if ((*List)[Index] == Window) {
				return;
			}
			++Index;
		}

		// Add to list, if not a reused window
		*List = realloc(*List, sizeof(GtkWindow *) * (Index + 2));
		(*List)[Index] = Window;
		(*List)[Index + 1] = NULL;
	}
}

void GTKNoCSDHandlerFailExit(void) {
	// Simple exit function when crash handler setup failed

	G_GNUC_UNUSED ssize_t Ignore = write(3, "1", 1);
	GTKNoCSDCrashPid = -2;
	_exit(0);
}

GtkWidget *GTKNoCSDSetUpSearchButton(GtkWidget *Container,
	bool (*Check) (GObject *), const char *ActiveProperty) {
	// Set up a search button

	// Get widget to be bound to
	GtkWidget *ChooserWidget = GTKNoCSDGTK3FindWidget(Container, Check);

	// Create search button
	// WARNING: Own call
	GtkWidget *Icon = g_object_new(GTKNoCSDGTKImage, "visible",
			ChooserWidget != NULL,
			"icon-name", "edit-find-symbolic", NULL);
	GtkWidget *SearchButton = g_object_new(GTKNoCSDGTKToggleButton,
			"child", Icon, "visible", ChooserWidget != NULL, NULL);

	// Bind properties
	if (ChooserWidget != NULL) {
		o_g_object_bind_property((GObject *) ChooserWidget,
			ActiveProperty, (GObject *) SearchButton, "active",
			G_BINDING_SYNC_CREATE | G_BINDING_BIDIRECTIONAL);
	}

	return SearchButton;
}

GtkWidget *GTKNoCSDSetUpFileChooser(GtkFileChooser *Chooser, bool Set,
	GtkWidget *Add) {
	// Fully set up file choosers

	// Get current extra widget
	GtkWidget *Extra = o_gtk_file_chooser_get_extra_widget(Chooser);

	if (Extra == NULL || strcmp(o_gtk_widget_get_name(Extra),
		"GTKNoCSD") != 0) {
		// Either there is no current widget or it is not ours, transfering

		// Create grid
		GtkWidget *ExtraGrid = o_gtk_grid_new();
		o_gtk_widget_set_name(ExtraGrid, "GTKNoCSD");

		// Create and add search button
		GtkWidget *SearchButton = GTKNoCSDSetUpSearchButton(
			(GtkWidget *) Chooser, GTKNoCSDGtkFileChooserWidget, "search-mode");
		o_gtk_grid_attach((GtkGrid *) ExtraGrid, SearchButton, 0, 0, 1, 1);

		if (Extra != NULL) {
			// Extra exists

			// If replaced, the variable is just replaced, otherwise it is
			// referenced for keeping it alive
			if (Set) {
				Extra = Add;
			} else {
				o_g_object_ref((GObject *) Extra);
			}

			// Unparent original
			o_gtk_file_chooser_set_extra_widget(Chooser, NULL);

			// Add either new or previous, if previous, remove the reference
			o_gtk_grid_attach((GtkGrid *) ExtraGrid, Extra, 1, 0, 1, 1);
			if (!Set) {
				o_g_object_unref((GObject *) Extra);
			}
		} else if (Set && Add != NULL) {
			// If there was no previous, but one is to be added, add it
			o_gtk_grid_attach((GtkGrid *) ExtraGrid, Add, 1, 0, 1, 1);
		}

		// Set our own as extra widget
		o_gtk_file_chooser_set_extra_widget(Chooser, ExtraGrid);
	} else if (Set) {
		// In this case our own was already set, but the application wants to
		// replace it

		// Remove previous if it existed
		o_gtk_grid_remove_column((GtkGrid *) Extra, 1);

		// Add new if it exists
		if (Add != NULL) {
			o_gtk_grid_attach((GtkGrid *) Extra, Add, 1, 0, 1, 1);
		}

		return Add;
	}

	return Extra;
}

void GTKNoCSDLoadCSS(const char *CSS) {
	// Load CSS for both GTK3 and GTK4

	GtkCssProvider *Provider = o_gtk_css_provider_new();
	if (GTKNoCSDGTKVersion == 4) {
		o_gtk_css_provider_load_from_string(Provider, CSS);
		o_gtk_style_context_add_provider_for_display(
			o_gdk_display_get_default(), (GtkStyleProvider *) Provider,
			GTK_STYLE_PROVIDER_PRIORITY_USER);
	} else {
		o_gtk_css_provider_load_from_data(Provider, CSS, -1, NULL);
		void *Screen = o_gdk_screen_get_default();
		o_gtk_style_context_add_provider_for_screen(Screen,
			(GtkStyleProvider *) Provider, GTK_STYLE_PROVIDER_PRIORITY_USER);
	}
	o_g_object_unref((GObject *) Provider);
}

int GTKNoCSDMagic(GtkWindow *Window, size_t Options) {
	// Do all needed changes to disable CSD
	// Options: 0: Nothing, 1: No layout loading, 2: Retry later on no child
	// with GTK4, 3: Same as 2 with GTK3

	// This is most likely an application bug
	if (Window == NULL) {
		return 1;
	}

	// Set up crash handler
	if (GTKNoCSDCrashPid == -3) {
		// Create crash handler
		struct sigaction Action = {0};
		Action.sa_sigaction = GTKNoCSDAction;
		sigemptyset(&Action.sa_mask);
		Action.sa_flags = SA_SIGINFO;

		// Set up handler for possible crash signals, save original handlers
		sigaction(SIGSEGV, &Action, &GTKNoCSDSEGVAction);
		sigaction(SIGABRT, &Action, &GTKNoCSDABRTAction);
		sigaction(SIGFPE,  &Action, &GTKNoCSDFPEAction);
		sigaction(SIGILL,  &Action, &GTKNoCSDILLAction);
		sigaction(SIGBUS,  &Action, &GTKNoCSDBUSAction);

		if (GTKNoCSDLD == NULL || GTKNoCSDArguments == NULL) {
			// If Crash handler starter or arguments were not found, exit
			GTKNoCSDCrashPid = -2;
		} else {
			Dl_info Information;
			if (dladdr((void *) (uintptr_t) &GTKNoCSDMagic,
				&Information) == 0) {
				// If library name was not found, exit
				GTKNoCSDCrashPid = -2;
			} else {
				char *LibraryFullPath = realpath(Information.dli_fname, NULL);

				if (LibraryFullPath == NULL || LibraryFullPath[0] ==  '\0') {
					// If library full path was not found, exit
					GTKNoCSDCrashPid = -2;
				} else {
					// Set up anonymous pipe with no blocking in child direction
					G_GNUC_UNUSED int Ignore = pipe(GTKNoCSDPipeToChild);
					Ignore = pipe(GTKNoCSDPipeToParent);
					fcntl(GTKNoCSDPipeToChild[0], F_SETFL, O_NONBLOCK);
					Ignore = pipe(GTKNoCSDPipeToChildEnd);

					GTKNoCSDCrashPid = fork();
					if (GTKNoCSDCrashPid == 0) {
						// Finalize pipe directions, make copies
						close(GTKNoCSDPipeToChild[1]);
						dup2(GTKNoCSDPipeToParent[1], TO_PARENT_COPY);
						close(GTKNoCSDPipeToParent[0]);
						dup2(GTKNoCSDPipeToChild[0], TO_CHILD_COPY);
						close(GTKNoCSDPipeToChildEnd[1]);
						dup2(GTKNoCSDPipeToChildEnd[0], TO_CHILD_END_COPY);

						// Start assembling arguments for starting crash handler
						char *NewArguments[GTKNoCSDArgumentNumber + 3];
						NewArguments[0] = GTKNoCSDLD;
						NewArguments[1] = LibraryFullPath;

						// Try to fetch full path, if not found use as is
						NewArguments[2] =
							o_g_find_program_in_path(GTKNoCSDArguments[0]);
						if (NewArguments[2] == NULL) {
							NewArguments[2] = GTKNoCSDArguments[0];
						}

						// If real executed file is not found, exit. This is
						// important for scripts, which will have the
						// interpreter as first command instead of the script
						if (NewArguments[2] == NULL) {
							GTKNoCSDHandlerFailExit();
						}

						// Copy arguments except binary
						for (size_t Index = 1;
							Index <= GTKNoCSDArgumentNumber; ++Index) {
							NewArguments[Index + 2] = GTKNoCSDArguments[Index];
						}

						// Appimages should be completely restarted, instead of
						// just the binary. This is detected and handled here
						// Check if binary is path and APPIMAGE is set
						char *AppImage = getenv("APPIMAGE");
						char *Ending = strrchr(NewArguments[2], '/');
						if (Ending != NULL && AppImage != NULL) {
							size_t Length = strlen(NewArguments[2]) -
								strlen(Ending);
							char *AppRun = malloc(Length + 7);
							if (AppRun != NULL) {
								// If so, copy folder name into variable, add
								// AppRun, check if file and appimage both exist
								strncpy(AppRun, NewArguments[2], Length);
								AppRun[Length] = '\0';
								strcat(AppRun, "/AppRun");
								struct stat Stat;
								if (stat(AppRun, &Stat) == 0 && stat(AppImage,
									&Stat) == 0) {
									// If so, replace binary with AppImage
									NewArguments[2] = AppImage;
								}
								free(AppRun);
							}
						}

						// Stop ld-musl from preloading the library into itself
						GTKNoCSDUnsetLDPreload();

						// Start crash handler
						execve(GTKNoCSDLD, NewArguments, environ);

						// This should not be reached, execve failed
						GTKNoCSDHandlerFailExit();
					} else {
						// Finalize pipe directions
						close(GTKNoCSDPipeToChild[0]);
						close(GTKNoCSDPipeToParent[1]);

						// Set up function on successful exit, to not restart
						atexit(GTKNoCSDExit);

						// Blocking, wait for handshake to avoid race conditions
						char Buffer;
						G_GNUC_UNUSED ssize_t Ignore =
							read(GTKNoCSDPipeToParent[0], &Buffer, 1);
					}
				}
				free(LibraryFullPath);
			}
		}
	}

	// Hook all windows if not already done
	GTKNoCSDHooker();

	bool SetCSS = false;
	if (!GTKNoCSDSettings) {
		GtkSettings *Settings = o_gtk_settings_get_default();
		if (Settings != NULL) {
			// Disable .ui dialog headers
			o_g_object_set((GObject *) Settings, "gtk-dialogs-use-header",
				FALSE, NULL);

			// If theme was set from environment
			if (GTKNoCSDTheme != NULL) {
				const char *Colon = strchr(GTKNoCSDTheme, ':');
				if (Colon == NULL) {
					// If dark preference was not set, set as it was given
					o_g_object_set((GObject *) Settings, "gtk-theme-name",
						GTKNoCSDTheme, NULL);
				} else {
					// If dark preference was set

					// Copy into local variable, cut off dark preference
					char *Theme = strdup(GTKNoCSDTheme);
					Theme[strlen(Theme) - strlen(Colon)] = '\0';

					// Set theme, free local copy
					o_g_object_set((GObject *) Settings, "gtk-theme-name",
						Theme, NULL);
					free(Theme);

					// Get dark preference
					bool Dark = strcmp(Colon + 1, "dark") == 0;
					AdwColorScheme Scheme = ADW_COLOR_SCHEME_FORCE_LIGHT;
					Scheme = Dark ? ADW_COLOR_SCHEME_FORCE_DARK : Scheme;

					// Get functions for the GTK version
					AdwStyleManager * (*GetDefault) (void) =
						o_adw_style_manager_get_default;
					void (*SetScheme) (AdwStyleManager *, AdwColorScheme) =
						o_adw_style_manager_set_color_scheme;
					if (GTKNoCSDGTKVersion == 3) {
						GetDefault = o_hdy_style_manager_get_default;
						SetScheme = o_hdy_style_manager_set_color_scheme;
					}

					// Enforce LibAdwaita or LibHandy color scheme
					if (GetDefault != NULL && SetScheme != NULL) {
						SetScheme(GetDefault(), Scheme);
					}

					// Set dark preference
					o_g_object_set((GObject *) Settings,
						"gtk-application-prefer-dark-theme", Dark, NULL);
				}
			}

			if (!GTKNoCSDNoCSS) {
				// Remove rounding, padding, shadow, hide title
				GTKNoCSDLoadCSS("window { border-radius: 0; box-shadow: none; }"
					"headerbar { border-radius: 0; min-height: 0pt; padding: 0pt; }"
					"headerbar * { margin: 0pt; }"
					"windowtitle { opacity: 0; }"
					"decoration { margin: 0px; }"
					"headerbar viewswitcher * { padding: 0pt; min-height: 0pt; }");

				// Some themes might not play well with the internal CSD, give
				// it too much padding. Here it is optionally removed
				if (GTKNoCSDCSDPadding) {
					GTKNoCSDLoadCSS(
						".default-decoration windowcontrols * { padding: unset; }");
				}

				// Force reload current window. We do it later, when we know
				// that it is needed and where the weak reference is stored
				SetCSS = GTKNoCSDGTKVersion != 4;
			}

			GTKNoCSDSettings = true;
		}
	}

	if (!GTKNoCSDLayout && Options != 1 && !GTKNoCSDCSD) {
		GtkSettings *Settings = o_gtk_settings_get_default();
		if (Settings != NULL) {
			// Remove titlebar buttons
			o_g_object_set((GObject *) Settings, "gtk-decoration-layout", "",
				NULL);

			GTKNoCSDLayout = true;
		}
	}

	// GTK3 windows can be embedded into some other widgets
	if (GTKNoCSDGTKVersion == 3 &&
		o_gtk_widget_get_parent((GtkWidget *) Window) != NULL) {
		return 2;
	}

	// Never touch inspector windows
	const char *WindowName = o_gtk_widget_get_name((GtkWidget *) Window);
	if (strstr(WindowName, "GtkInspectorWindow") == WindowName) {
		return 3;
	}

	// Popup windows in GTK3 are not needed
	if (GTKNoCSDGTKVersion == 3) {
		if (o_gtk_window_get_window_type(Window) == 1) {
			return 4;
		}
		int Hint = o_gtk_window_get_type_hint(Window);
		if (2 < Hint && Hint != 5) {
			return 5;
		}
	}

	// Lomiri does not decorate windows that are transient for another.
	// To work around this, the setting of the property is delayed to after they
	// got mapped. However since this breaks window centering on other systems
	// (XFCE, possibly everything X11), it will not be done anywhere else
	if (GTKNoCSDOnLomiri) {
		if (!o_g_signal_handler_find((GObject *) Window, G_SIGNAL_MATCH_FUNC,
			0, 0, NULL, (GCallback *) GTKNoCSDChangeTransient, NULL)) {
			// WARNING: Macro
			g_signal_connect(Window, "notify::transient-for",
				G_CALLBACK(GTKNoCSDChangeTransient), NULL);
			g_signal_connect(Window, "unmap",
				G_CALLBACK(GTKNoCSDChangeTransient), NULL);
		}

		// Also do it for windows that already came with the property set
		GTKNoCSDChangeTransient(Window, NULL, NULL);
	}

	// Guarantees that each window will only go through this once.
	size_t Index = 0;
	if (GTKNoCSDWindowList == NULL) {
		GTKNoCSDWindowList = malloc(sizeof(GtkWindow * *) * 2);

		// Windows stored as weak pointers
		// WARNING: Macro
		GTKNoCSDWindowList[0] = g_new0(GtkWindow *, 1);
		*GTKNoCSDWindowList[0] = Window;
		o_g_object_add_weak_pointer((GObject *) Window,
			(gpointer *) GTKNoCSDWindowList[0]);

		GTKNoCSDWindowList[1] = NULL;
	} else {
		bool Add = true;
		while (GTKNoCSDWindowList[Index] != NULL) {
			if (GTKNoCSDWindowList[Index][0] == Window) {
				// A window might get unrealized, set a header then get
				// realized. It is detected here and the header is put back to
				// the appropriate container
				if (GTKNoCSDTest(GTKNoCSDWindowGetChild(Window))) {
					GtkWidget *PossiblyHeader =
						o_gtk_window_get_titlebar(Window);
					if (PossiblyHeader != NULL) {
						o_g_object_ref((GObject *) PossiblyHeader);
						o_gtk_window_set_titlebar(Window, NULL);

						// WARNING: Own call
						gtk_window_set_titlebar(Window, PossiblyHeader);
						o_g_object_unref((GObject *) PossiblyHeader);
						return 6;
					}
				}

				// GTK Sometimes reuses windows and turns CSD back on. Bad GTK
				if (!GTKNoCSDAdwApplicatonWindow((GObject *) Window) &&
					!GTKNoCSDAdwWindow((GObject *) Window) &&
					!GTKNoCSDHdyApplicatonWindow((GObject *) Window) &&
					!GTKNoCSDHdyWindow((GObject *) Window) &&
					!GTKNoCSDTest(GTKNoCSDWindowGetChild(Window))) {
					Add = false;
					break;
				}
				return 7;
			}
			++Index;
		}

		// Add to list, if not a reused window
		if (Add) {
			GTKNoCSDWindowList = realloc(GTKNoCSDWindowList,
					sizeof(GtkWindow * *) * (Index + 2));

			// Windows stored as weak pointers
			// WARNING: Macro
			GTKNoCSDWindowList[Index] = g_new0(GtkWindow *, 1);
			*GTKNoCSDWindowList[Index] = Window;
			o_g_object_add_weak_pointer((GObject *) Window,
				(gpointer *) GTKNoCSDWindowList[Index]);

			GTKNoCSDWindowList[Index + 1] = NULL;
		}
	}

	// Add search button to file choosers if needed
	if (GTKNoCSDGTKVersion == 3 &&
		GTKNoCSDGtkFileChooserDialog((GObject *) Window)) {
		GTKNoCSDSetUpFileChooser((GtkFileChooser *) Window, false, NULL);
	}

	// Application windows might have a shortcuts window, check and add back
	// titlebar to that tool. The window might get added later, so we check then
	if (GTKNoCSDGtkApplicatonWindow((GObject *) Window)) {
		o_g_timeout_add(1, GTKNoCSDHandleShortcutsWindow,
			GTKNoCSDWindowList[Index]);
	}

	if (!GTKNoCSDNoCSS) {
		// This CSS breaks the look of context menus on X, with GTK3, if loaded
		// globally, but it is needed for certain windows (Peek?)
		GtkCssProvider *Provider = o_gtk_css_provider_new();
		GtkStyleContext *Style =
			o_gtk_widget_get_style_context((GtkWidget *) Window);
		const char *CSS = "decoration { box-shadow: none; }";
		if (GTKNoCSDGTKVersion == 4) {
			o_gtk_css_provider_load_from_string(Provider, CSS);
		} else {
			o_gtk_css_provider_load_from_data(Provider, CSS, -1, NULL);
		}
		o_gtk_style_context_add_provider(Style,
			(GtkStyleProvider *) Provider, GTK_STYLE_PROVIDER_PRIORITY_USER);
		o_g_object_unref((GObject *) Provider);
	}

	// Reset CSS to apply it on current window
	if (SetCSS) {
		o_g_idle_add(GTKNoCSDGTK3CurrentWindowStyle, GTKNoCSDWindowList[Index]);
	}

	// Make sure the application always has the signal to add SSD to all windows
	GtkApplication *Application = o_gtk_window_get_application(Window);
	if (Application != NULL) {
		if (o_g_signal_handler_find((GObject *) Application,
			G_SIGNAL_MATCH_FUNC, 0, 0, NULL,
			(GCallback *) GTKNoCSDWindowAdded, NULL) == 0) {
			// WARNING: Macro
			g_signal_connect(Application, "window-added",
				G_CALLBACK(GTKNoCSDWindowAdded), NULL);
		}
	} else if (o_g_signal_handler_find((GObject *) Window, G_SIGNAL_MATCH_FUNC,
		0, 0, NULL, (GCallback *) GTKNoCSDApplicationChanged, NULL) == 0) {
		// WARNING: Macro
		g_signal_connect(Window, "notify::application",
			G_CALLBACK(GTKNoCSDApplicationChanged), NULL);
	}

	GtkWidget *Header = o_gtk_window_get_titlebar(Window);

	// Try to get header from GTKNoCSDTitleBar. Liferea specific fix
	if (Header == NULL && GTKNoCSDGTKVersion == 4) {
		Header = o_g_object_get_data((GObject *) Window, "GTKNoCSDTitleBar");
	}

	// LibAdwaita and LibHandy windows need special treatment
	if (GTKNoCSDAdwApplicatonWindow((GObject *) Window) ||
		GTKNoCSDAdwWindow((GObject *) Window) ||
		GTKNoCSDHdyApplicatonWindow((GObject *) Window) ||
		GTKNoCSDHdyWindow((GObject *) Window)) {
		// If LibAdwaita or LibHandy window

		// If header not found, come back later
		if (Header == NULL) {
			// Remove window from list of windows done
			int Index = 0;
			while (GTKNoCSDWindowList[Index] != NULL) {
				++Index;
			}
			GTKNoCSDWindowList[Index - 1] = NULL;

			// Call removal later
			o_g_timeout_add(1, GTKNoCSDRecall, Window);
			return 0;
		}

		// Hide the title widget, if it is not a special control. It might be
		// added later so we check then
		o_g_timeout_add(1, GTKNoCSDGTKVersion == 4 ?
			GTKNoCSDSetGTK4Headers : GTKNoCSDSetGTK3Headers, Window);

		if (GTKNoCSDGTKVersion == 3) {
			// Unset the header for the window, but save it for returning it in
			// gtk_window_get_titlebar
			o_g_object_ref((GObject *) Header);
			o_gtk_window_set_titlebar(Window, NULL);
			o_g_object_set_data((GObject *) Window, "GTKNoCSDTitleBar", Header);
			return 8;
		}
	}

	// GTK3/GTK4 and LibAdwaita also need to rearrange widgets

	// Get top child of window
	GtkWidget *WindowChild = GTKNoCSDWindowGetChild(Window);

	if (GTKNoCSDGtkShortcutsWindow((GObject *) Window)) {
		// This window was already dealt with
		if (strcmp(o_gtk_widget_get_name((GtkWidget *) Window),
			"GTKNoCSDHelp") == 0) {
			return 9;
		}
		o_gtk_widget_set_name((GtkWidget *) Window, "GTKNoCSDHelp");

		// GtkShortcutsWindow has a regular label as title, and does not set the
		// the window title. Here we name the window by the translated title in
		// the label and set it to empty, so it is not visible
		GtkWidget *Title;
		if (GTKNoCSDGTKVersion == 3) {
			Title =
				o_gtk_header_bar_get_custom_title((GtkHeaderBar *) Header);
		} else {
			Title = o_gtk_header_bar_get_title_widget((GtkHeaderBar *) Header);
		}
		Title = GTKNoCSDFirstChild(Title);
		o_gtk_window_set_title(Window,
			o_gtk_label_get_text((GtkLabel *) Title));
		o_gtk_label_set_label((GtkLabel *) Title, "");

		// In GTK3 ShortcutsWindows cannot get their content replaced. The
		// search button needs to be recreated
		if (GTKNoCSDGTKVersion == 3) {
			// The header is kept alive as it might be used internally
			o_g_object_ref((GObject *) Header);
			o_gtk_window_set_titlebar(Window, NULL);

			// Create search button, add it to window
			GtkWidget *SearchButton = GTKNoCSDSetUpSearchButton(WindowChild,
					GTKNoCSDGtkSearchBar, "search-mode-enabled");
			GTKNoCSDGtkBoxAdd(WindowChild, SearchButton);

			// Make button the first widget, move it to the left
			o_gtk_box_reorder_child((GtkBox *) (WindowChild), SearchButton, 0);
			o_gtk_widget_set_halign(SearchButton, GTK_ALIGN_START);

			return 10;
		}
	}

	// Do not touch windows that have no header bar
	if (Header == NULL) {
		return 11;
	}

	// Glade is for designing graphical user interfaces, like Cambalache
	// The library is not needed to run there
	// WARNING: Macro
	if (strcmp("GladePlaceholder", o_g_type_name(G_OBJECT_TYPE(Header))) == 0) {
		return 12;
	}

	// Certain applications turn off decorations while having CSD, it is turned
	// back here. These windows are tracked as gdk_window_get_frame_extents only
	// applies to them
	if (!o_gtk_window_get_decorated(Window)) {
		GTKNoCSDAddToList(&GTKNoCSDUndecoratedWindowList, Window);
		o_gtk_window_set_decorated(Window, true);
	}

	// Both checks need the window to have content and only appear on GTK4
	// First check: LibAdwaita dialogs only need the titlebar removed
	// Second check: Celluloid uses a regular window, but adds a LibAdwaita
	// headerbar into it. If it is detected, the empty titlebar is just removed
	if (WindowChild != NULL && GTKNoCSDGTKVersion == 4 &&
		(GTKNoCSDAdwDialog((GObject *) WindowChild) ||
		GTKNoCSDGetGTK4Headers(WindowChild, true) != NULL)) {
		o_gtk_window_set_titlebar(Window, NULL);
		return 13;
	}

	// Unset the application menu on GTK3 for applications that have CSD
	// Not sure if this is the right approach. BleachBit has the same menu twice
	// otherwise
	if (Application != NULL && GTKNoCSDGTKVersion == 3) {
		o_gtk_application_set_app_menu(Application, NULL);
	}

	if (WindowChild == NULL) {
		// Builder might map a window and unset the child after. It is also
		// possible that such window depends on not getting unrealized later,
		// for example with WebKitWebView. So the titlebar removal happens
		// early, and later it will be added to the window. Liferea specific fix
		if (Options == 2 && GTKNoCSDGTKVersion == 4) {
			// Unset and save header
			o_g_object_ref((GObject *) Header);
			o_gtk_window_set_titlebar(Window, NULL);
			o_g_object_set_data((GObject *) Window, "GTKNoCSDTitleBar", Header);
		}

		// Come back later
		if ((Options == 3 && GTKNoCSDGTKVersion == 3) ||
			(Options == 2 && GTKNoCSDGTKVersion == 4)) {
			o_g_timeout_add(1, GTKNoCSDRecall, Window);
			return 14;
		}
	}

	// Create own vertical container
	GtkWidget *Vertical = o_gtk_grid_new();
	o_gtk_widget_set_name(Vertical, "GTKNoCSD");

	// Have 2 boxes at all times to contain the header and the content
	GtkWidget *HeaderBox = o_gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
	GtkWidget *ContentBox = o_gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
	o_gtk_grid_attach((GtkGrid *) Vertical, HeaderBox, 0, 0, 1, 1);
	o_gtk_grid_attach((GtkGrid *) Vertical, ContentBox, 0, 1, 1, 10000);

	// Grid has no order guarantee, these GObject properties are used instead
	o_g_object_set_data((GObject *) Vertical, "HeaderBox", HeaderBox);
	o_g_object_set_data((GObject *) Vertical, "ContentBox", ContentBox);

	// Name for easy identification when going up widget tree
	o_gtk_widget_set_name(ContentBox, "GTKNoCSDContentBox");

	// Remove widget from window, add it to own box, if it exists
	if (WindowChild != NULL) {
		o_g_object_ref((GObject *) WindowChild);
		GTKNoCSDWindowSetChild(Window, NULL);
		o_gtk_widget_set_vexpand(WindowChild, TRUE);
		o_gtk_widget_set_hexpand(WindowChild, TRUE);
		GTKNoCSDGtkBoxAdd(ContentBox, WindowChild);
		o_g_object_unref((GObject *) WindowChild);
	}

	// Add everything back to window
	GTKNoCSDWindowSetChild(Window, Vertical);

	// Take header and add into our own box

	o_g_object_ref((GObject *) Header);
	o_gtk_window_set_titlebar(Window, NULL);

	if (GTKNoCSDGTKVersion == 4) {
		// Add to our own widget, which handles visibility
		// WARNING: Own call
		GtkWidget *Revealer = g_object_new(GTKNoCSDBox_get_type(), NULL);

		// Name for easy identification when going up widget tree
		o_gtk_widget_set_name(Revealer, "GTKNoCSDHeaderBox");

		o_gtk_widget_set_layout_manager(Revealer, NULL);
		o_gtk_box_append((GtkBox *) HeaderBox, Revealer);
		o_gtk_box_append((GtkBox *) Revealer, Header);

		// LibAdwaita windows were already checked, AdwGizmo is a placeholder
		if (!GTKNoCSDAdwApplicatonWindow((GObject *) Window) &&
			!GTKNoCSDAdwWindow((GObject *) Window)) {
			// WARNING: Macro
			if (strcmp("AdwGizmo", o_g_type_name(G_OBJECT_TYPE(Header))) != 0) {
				o_g_timeout_add(1, GTKNoCSDSetGTK4Headers, Header);
			}
		}

		// Unset everything set by the Liferea specific fix
		if (o_g_object_get_data((GObject *) Window,
			"GTKNoCSDTitleBar") != NULL) {
			o_g_object_set_data((GObject *) Window, "GTKNoCSDTitleBar", NULL);
			o_g_object_unref((GObject *) Header);
		}
	} else {
		// GTK3 rearranging

		o_gtk_widget_set_visible((GtkWidget *) Vertical, true);
		o_gtk_widget_set_visible((GtkWidget *) ContentBox, true);

		o_gtk_widget_set_visible(HeaderBox, true);
		o_gtk_container_set_border_width(Window, 0);

		// Create event box for drag/right click

		GtkWidget *EventBox = o_gtk_event_box_new();

		// Name for easy identification when going up widget tree
		o_gtk_widget_set_name(EventBox, "GTKNoCSDHeaderBox");

		// Make event box react to drag/right click
		// WARNING: Macro
		g_signal_connect(EventBox, "button-press-event",
			G_CALLBACK(GTKNoCSDGTK3EventBoxActions), Window);

		// Set up function and add to regular Revealer
		// WARNING: Macro
		g_signal_connect(Header, "size-allocate",
			G_CALLBACK(GTKNoCSDGTK3HeaderSizeAllocate), NULL);
		GtkWidget *Revealer = o_gtk_revealer_new();
		o_gtk_revealer_set_transition_duration((GtkRevealer *) Revealer, 0);
		o_gtk_container_add(Revealer, EventBox);
		o_gtk_widget_set_visible(Revealer, true);
		o_gtk_container_add(EventBox, Header);

		// Add finalized header to container, display everything
		o_gtk_container_add(HeaderBox, Revealer);
		o_gtk_widget_set_visible(EventBox, true);

		// Remove extra close buttons
		GTKNoCSDGetGTK3Headers(Header);

		// Lutris center widget got stuck on wrong size
		o_gtk_container_check_resize(Window);
	}
	o_g_object_unref((GObject *) Header);

	return 15;
}

void GTKNoCSDAboutClose(GtkWidget *Dialog) {
	// Close About window when close button is clicked in GTK3
	o_gtk_widget_destroy(Dialog);
}

GtkWidget *GTKNoCSDGTK4Content(GtkWidget *Child) {
	// Get content of vertical or if not vertical, return as is

	if (GTKNoCSDTest(Child)) {
		// ContentBox, real child
		return o_gtk_widget_get_last_child(
			o_g_object_get_data((GObject *) Child, "ContentBox"));
	}

	return Child;
}

gboolean GTKNoCSDRedisplayContent(gpointer Data) {
	// Display the content of the window again

	GtkWidget *Child = GTKNoCSDWindowGetChild((GtkWindow *) Data);
	if (Child != NULL) {
		o_gtk_widget_set_visible(Child, false);
		o_gtk_widget_set_visible(Child, true);
	}

	return FALSE;
}

void gtk_window_present(GtkWindow *Window) {
	// Entry point used by certain apps to display the window.
	// Hook it, execute our own function then the original

	GTKNoCSDGetReferences(true);

	// Only present window on successful run, unless in GTK2
	if (2 < GTKNoCSDGTKVersion) {
		int MagicStatus = GTKNoCSDMagic(Window, 0);
		if (MagicStatus) {
			// This status is what Lutris produces and which is the only window
			// needing this fix
			if (GTKNoCSDGTKVersion == 3 && MagicStatus == 7 &&
				!o_gtk_widget_get_mapped((GtkWidget *) Window)) {
				o_g_idle_add(GTKNoCSDRedisplayContent, Window);
			}

			o_gtk_window_present(Window);
		}
		return;
	}

	o_gtk_window_present(Window);
}

void gtk_widget_set_visible(GtkWidget *Widget, gboolean Visible) {
	// Entry point used by certain apps to display widgets.
	// Hook it, execute our own function then the original

	GTKNoCSDGetReferences(true);

	o_gtk_widget_set_visible(Widget, Visible);

	// Not in GTK2
	if (2 < GTKNoCSDGTKVersion) {
		// This function might not get called with the window
		GtkWidget *Window = GTKNoCSDGetWindow(Widget);
		if (Window != NULL && Visible) {
			GTKNoCSDMagic((GtkWindow *) Window, Window == Widget ? 0 : 3);
		}
	}
}

GtkWidget *gtk_file_chooser_get_extra_widget(GtkFileChooser *Chooser) {
	// Set up file choosers with search button and get extra widget

	GTKNoCSDGetReferences(true);

	// Not in GTK2
	if (GTKNoCSDGTKVersion == 2) {
		return o_gtk_file_chooser_get_extra_widget(Chooser);
	}

	// Add search button to file choosers if needed, get extra widget
	return GTKNoCSDSetUpFileChooser(Chooser, false, NULL);
}

void gtk_file_chooser_set_extra_widget(GtkFileChooser *Chooser,
	GtkWidget *Extra) {
	// Set up file choosers with search button and set extra widget

	GTKNoCSDGetReferences(true);

	// Not in GTK2
	if (GTKNoCSDGTKVersion == 2) {
		o_gtk_file_chooser_set_extra_widget(Chooser, Extra);
		return;
	}

	// Add search button to file choosers if needed, set extra widget
	GTKNoCSDSetUpFileChooser(Chooser, true, Extra);
}

// The goal of these is to "hide" Vertical through APIs

void gtk_container_add(GtkWidget *Container, GtkWidget *Widget) {
	// GTK3 uses this to add children to widgets, potentially to the window too
	// Hook it and add the widget to our box if already transformed, if not then
	// add and then transform it

	GTKNoCSDGetReferences(true);

	if (2 < GTKNoCSDGTKVersion && Container == GTKNoCSDGetWindow(Container)) {
		GtkWidget *WindowChild = GTKNoCSDFirstChild(Container);
		if (GTKNoCSDTest(WindowChild)) {
			GtkWidget *ContentBox = o_g_object_get_data(
				(GObject *) WindowChild, "ContentBox");

			// Remove existing child if present
			GtkWidget *OldContent = GTKNoCSDFirstChild(ContentBox);
			if (OldContent != NULL) {
				o_gtk_container_remove(ContentBox, OldContent);
			}

			o_gtk_container_add(ContentBox, Widget);
			o_gtk_widget_set_vexpand(Widget, TRUE);
			o_gtk_widget_set_hexpand(Widget, TRUE);
		} else {
			o_gtk_container_add(Container, Widget);
			GTKNoCSDMagic((GtkWindow *) Container, 0);
		}
		return;
	}

	o_gtk_container_add(Container, Widget);
}

GtkWidget *gtk_window_get_child(GtkWindow *Window) {
	// Get the child under Vertical, if the child is requested

	GTKNoCSDGetReferences(true);

	return GTKNoCSDGTK4Content(o_gtk_window_get_child(Window));
}

void gtk_window_set_child(GtkWindow *Window, GtkWidget *Child) {
	// Get the child under Vertical, if the child is set

	GTKNoCSDGetReferences(true);

	GtkWidget *WindowChild = o_gtk_window_get_child(Window);
	if (GTKNoCSDTest(WindowChild)) {
		// Remove existing child if present
		GtkWidget *ContentBox = o_g_object_get_data((GObject *) WindowChild,
				"ContentBox");
		GtkWidget *OldContent = o_gtk_widget_get_last_child(ContentBox);
		if (OldContent != NULL) {
			o_gtk_widget_unparent(OldContent);
		}

		o_gtk_box_append((GtkBox *) ContentBox, Child);
		o_gtk_widget_set_vexpand(Child, TRUE);
		o_gtk_widget_set_hexpand(Child, TRUE);
		return;
	}

	o_gtk_window_set_child(Window, Child);
	GTKNoCSDMagic(Window, 0);
}

GtkWidget *gtk_widget_get_parent(GtkWidget *Widget) {
	// Get the window if the parent is requested

	GTKNoCSDGetReferences(true);

	// EventBox on GTK3, Revealer on GTK4
	GtkWidget *Parent = o_gtk_widget_get_parent(Widget);

	if (Parent == NULL || GTKNoCSDGTKVersion == 2) {
		return Parent;
	}

	if (strcmp(o_gtk_widget_get_name(Parent), "GTKNoCSDContentBox") == 0 ||
		strcmp(o_gtk_widget_get_name(Parent), "GTKNoCSDHeaderBox") == 0) {
		return GTKNoCSDGetWindow(Parent);
	}

	return Parent;
}

GtkWidget *gtk_widget_get_first_child(GtkWidget *Widget) {
	// If the windows first child is requested, get last of Vertical

	GTKNoCSDGetReferences(true);

	return GTKNoCSDGTK4Content(o_gtk_widget_get_first_child(Widget));
}

GtkWidget *gtk_widget_get_last_child(GtkWidget *Widget) {
	// If the windows last child is requested, get last of Vertical

	GTKNoCSDGetReferences(true);

	return GTKNoCSDGTK4Content(o_gtk_widget_get_last_child(Widget));
}

GtkWidget *gtk_window_get_titlebar(GtkWindow *Window) {
	// If the titlebar is requested, return the one from Vertical

	GTKNoCSDGetReferences(true);

	// This is only used in LibHandy
	GtkWidget *Header = o_g_object_get_data((GObject *) Window,
			"GTKNoCSDTitleBar");
	if (Header != NULL && GTKNoCSDGTKVersion == 3) {
		return Header;
	}

	GtkWidget *WindowChild = GTKNoCSDWindowGetChild(Window);
	if (GTKNoCSDTest(WindowChild)) {
		GtkWidget *Box = GTKNoCSDFirstChild(
			o_g_object_get_data((GObject *) WindowChild, "HeaderBox"));

		// GTK3 has an extra GtkEventBox for drag/right click
		if (GTKNoCSDGTKVersion == 3) {
			return GTKNoCSDFirstChild(GTKNoCSDFirstChild(Box));
		}

		return GTKNoCSDFirstChild(Box);
	}

	return o_gtk_window_get_titlebar(Window);
}

void gtk_window_set_titlebar(GtkWindow *Window, GtkWidget *Header) {
	// If the titlebar is set, try to set our own first, if not possible, set
	// the window, but try to switch it back after. Not sure if the first half
	// is the proper solution, atomix breaks GTK otherwise

	GTKNoCSDGetReferences(true);

	// Celluloid specific fix. It uses a regular window, but adds a LibAdwaita
	// headerbar into it. If it is detected, it is not added
	if (GTKNoCSDGTKVersion == 4 && GTKNoCSDGetGTK4Headers((GtkWidget *) Window,
		true) != NULL) {
		return;
	}

	GTKNoCSDMagic(Window, 0);
	GtkWidget *WindowChild = GTKNoCSDWindowGetChild(Window);
	if (GTKNoCSDTest(WindowChild)) {
		GtkWidget *Box = GTKNoCSDFirstChild(
			o_g_object_get_data((GObject *) WindowChild, "HeaderBox"));

		// GTK3 has an extra GtkEventBox for drag/right click
		if (GTKNoCSDGTKVersion == 3) {
			Box = GTKNoCSDFirstChild(Box);
		}

		// Get current Header
		GtkWidget *OldHeader = GTKNoCSDFirstChild(Box);

		// If already added return
		if (OldHeader == Header) {
			return;
		}

		// If it exists and is different remove it
		if (OldHeader != NULL) {
			if (GTKNoCSDGTKVersion == 3) {
				o_gtk_container_remove(Box, OldHeader);
			} else {
				o_gtk_box_remove((GtkBox *) Box, OldHeader);
			}
		}

		// If new one exists, add it
		if (Header != NULL) {
			if (GTKNoCSDGTKVersion == 3) {
				o_gtk_container_add(Box, Header);
			} else {
				GTKNoCSDGtkBoxAdd(Box, Header);
			}
		}
	} else {
		o_gtk_window_set_titlebar(Window, Header);
		GTKNoCSDMagic(Window, 0);
	}
}

// All supported versions of GTK set title widget differently. When they do,
// they are rechecked for title labels

void gtk_header_bar_set_custom_title(GtkHeaderBar *Widget, GtkWidget *Title) {
	GTKNoCSDGetReferences(true);

	o_gtk_header_bar_set_custom_title(Widget, Title);
	if (Title != NULL) {
		// Unhide, if labels have hidden it, if needed it will get hidden again
		o_gtk_widget_set_visible((GtkWidget *) Widget, true);
		GTKNoCSDGetGTK3Headers(Title);
	}

	GTKNoCSDGTK3SetEmptyTitle((GtkWidget *) Widget, Title == NULL);
}

void hdy_header_bar_set_custom_title(void *Widget, GtkWidget *Title) {
	GTKNoCSDGetReferences(true);

	o_hdy_header_bar_set_custom_title(Widget, Title);
	if (Title != NULL) {
		// Unhide, if labels have hidden it, if needed it will get hidden again
		o_gtk_widget_set_visible((GtkWidget *) Widget, true);
		GTKNoCSDGetGTK3Headers(Title);
	}

	GTKNoCSDGTK3SetEmptyTitle((GtkWidget *) Widget, Title == NULL);
}

void gtk_header_bar_set_title_widget(GtkHeaderBar *Widget, GtkWidget *Title) {
	GTKNoCSDGetReferences(true);

	o_gtk_header_bar_set_title_widget(Widget, Title);
	if (Title != NULL) {
		GTKNoCSDGetGTK4Headers(Title, false);
	}
}

void adw_header_bar_set_title_widget(AdwHeaderBar *Widget, GtkWidget *Title) {
	GTKNoCSDGetReferences(true);

	o_adw_header_bar_set_title_widget(Widget, Title);
	if (Title != NULL) {
		GTKNoCSDGetGTK4Headers(Title, false);
	}
}

void gtk_window_set_decorated(GtkWindow *Window, gboolean Setting) {
	// An application might unset the decoration, while also having CSD
	// (picture in picture windows). It is disallowed and if detected, the
	// decoration is kept

	GTKNoCSDGetReferences(true);

	// Keep original behavior for GTK2
	if (GTKNoCSDGTKVersion == 2) {
		o_gtk_window_set_decorated(Window, Setting);
		return;
	}

	// Add window to list of undecorated windows if needed
	if (GTKNoCSDTest(GTKNoCSDWindowGetChild(Window)) && !Setting) {
		GTKNoCSDAddToList(&GTKNoCSDUndecoratedWindowList, Window);
	}

	o_gtk_window_set_decorated(
		Window, GTKNoCSDTest(GTKNoCSDWindowGetChild(Window)) || Setting);
}

void gtk_widget_reparent(GtkWidget *Widget, GtkWidget *Container) {
	// Certain applications use this to set window content
	// Hook it, execute our own reparenting, if the child is the top child of a
	// transformed window, move our own widget instead

	GTKNoCSDGetReferences(true);

	// WARNING: Own call
	// If something is missing or parent is set already, do not do anything
	if (Widget == NULL || Container == NULL ||
		gtk_widget_get_parent(Widget) == Container) {
		return;
	}

	// Only on GTK3
	if (GTKNoCSDGTKVersion == 3) {
		// Remove existing child if adding to window and present
		if (GTKNoCSDGtkWindow((GObject *) Container)) {
			GtkWidget *ContainerChild =
				GTKNoCSDWindowGetChild((GtkWindow *) Container);
			if (ContainerChild != NULL) {
				o_gtk_container_remove(Container, ContainerChild);
			}
		}

		// WARNING: Own call
		GtkWidget *Window = gtk_widget_get_parent(Widget);
		if (GTKNoCSDGtkWindow((GObject *) Window)) {
			// If in a window
			GtkWidget *WindowChild =
				GTKNoCSDWindowGetChild((GtkWindow *) Window);
			if (GTKNoCSDTest(WindowChild)) {
				// If in a transformed window, move entire transformed widget
				// into new container

				o_g_object_ref((GObject *) WindowChild);
				o_gtk_container_remove(Window, WindowChild);

				// WARNING: Own call
				// Also transform new container if needed
				gtk_container_add(Container, WindowChild);
				o_g_object_unref((GObject *) WindowChild);
				return;
			}
		}

		// If not transformed or not in a window, only move widget
		o_g_object_ref((GObject *) Widget);
		o_gtk_container_remove(Window, Widget);

		// WARNING: Own call
		// Also transform new container if needed
		gtk_container_add(Container, Widget);
		o_g_object_unref((GObject *) Widget);
		return;
	}

	o_gtk_widget_reparent(Widget, Container);
}

GtkWidget *GTKNoCSDFindWindowTitle(GtkWidget *Widget) {
	// Find window title widget in headerbar title widget

	// Check if widget is needed, return if it is
	if (GTKNoCSDAdwWindowTitle((GObject *) Widget)) {
		return Widget;
	}

	// Go through all children
	GtkWidget *Child = o_gtk_widget_get_first_child(Widget);
	while (Child != NULL) {
		// Check children of child, return if found, go to next child
		GtkWidget *Found = GTKNoCSDFindWindowTitle(Child);
		if (Found != NULL) {
			return Found;
		}
		Child = o_gtk_widget_get_next_sibling(Child);
	}

	return NULL;
}

GtkApplication *gtk_window_get_application(GtkWindow *Window) {
	// LibAdwaita dialogs that were split out might expect to have the same
	// application. That on the other hand would break many other parts. So a
	// custom property is set in adw_dialog_present, which is fetched here

	GTKNoCSDGetReferences(true);

	GtkApplication *Application = o_g_object_get_data((GObject *) Window,
			"GTKNoCSDApplication");
	return Application !=
		   NULL ? Application : o_gtk_window_get_application(Window);
}

void adw_dialog_present(AdwDialog *Child, GtkWidget *Parent) {
	// LibAdwaita uses embedded dialogs which break most themes. This pops them
	// out into their own window

	GTKNoCSDGetReferences(true);

	// Display dialog in own window
	o_adw_dialog_present(Child, NULL);

	// Hide title widget of dialog, if it only displays window title
	GtkWidget *HeaderBar = GTKNoCSDGetGTK4Headers((GtkWidget *) Child, true);
	if (HeaderBar != NULL) {
		GtkWidget *Title =
			o_adw_header_bar_get_title_widget((AdwHeaderBar *) HeaderBar);
		if (Title != NULL) {
			GtkWidget *WindowTitle = GTKNoCSDFindWindowTitle(Title);
			if (WindowTitle != NULL && o_gtk_widget_get_mapped(WindowTitle)) {
				o_adw_header_bar_set_title_widget((AdwHeaderBar *) HeaderBar,
					o_gtk_grid_new());
			}
		}
	}

	// Get window of dialog, empty window of parent
	GtkWindow *ChildWindow = (GtkWindow *) o_gtk_widget_get_ancestor(
		(GtkWidget *) Child, GTKNoCSDGTKWindow), *ParentWindow = NULL;

	// Always check first label in dialog, which can also be the title
	GtkWidget *Label = GTKNoCSDGTK4FindWidget((GtkWidget *) ChildWindow,
			GTKNoCSDGtkLabel);
	if (Label != NULL) {
		GTKNoCSDLabelParentCheck = false;
		GTKNoCSDLabelChange(Label);
		GTKNoCSDLabelParentCheck = true;
	}

	// Get window of parent
	if (Parent != NULL) {
		ParentWindow = (GtkWindow *) o_gtk_widget_get_ancestor(Parent,
				GTKNoCSDGTKWindow);
	}

	// Get original dialog size
	int Width = o_adw_dialog_get_content_width(Child), ParentWidth = Width;
	int Height = o_adw_dialog_get_content_height(Child), ParentHeight = Height;

	if (ParentWindow != NULL) {
		// Center dialog on parent, prevent closing parent while child exists
		o_gtk_window_set_transient_for(ChildWindow, ParentWindow);
		o_gtk_window_set_modal(ChildWindow, true);

		// Add application actions, set custom Application property, if present
		GtkApplication *Application =
			o_gtk_window_get_application(ParentWindow);
		if (Application != NULL) {
			o_gtk_widget_insert_action_group((GtkWidget *) Child, "app",
				(GActionGroup *) Application);
			o_g_object_set_data((GObject *) ChildWindow, "GTKNoCSDApplication",
				Application);
		}

		// Add window actions if supposed to be in an application window
		if (GTKNoCSDGtkApplicatonWindow((GObject *) ParentWindow)) {
			o_gtk_widget_insert_action_group((GtkWidget *) Child, "win",
				(GActionGroup *) ParentWindow);
		}

		// Get size of parent window
		ParentWidth = o_gtk_widget_get_width((GtkWidget *) ParentWindow);
		ParentHeight = o_gtk_widget_get_height((GtkWidget *) ParentWindow);
	}

	// Make windows at most as large as the parent, but resizeable
	o_adw_dialog_set_content_width(Child, MIN(ParentWidth, Width));
	o_adw_dialog_set_content_height(Child, MIN(ParentHeight, Height));
	o_gtk_window_set_resizable(ChildWindow, true);
}

AdwDialog *GTKNoCSDAdwDialogForWindow(GtkWindow *Window) {
	// Get dialog belonging to window

	AdwDialog *Dialog = NULL;

	// Go through all windows
	int Index = 0;
	while (GTKNoCSDWindowList[Index] != NULL) {
		GtkWindow *CheckedWindow = GTKNoCSDWindowList[Index][0];

		// Check if window still exists and belongs to asked window
		if (CheckedWindow != NULL &&
			o_gtk_window_get_transient_for(CheckedWindow) == Window) {
			// Check if window contains dialog and set it if so
			// No break so the last created window is returned
			GtkWidget *Content =
				GTKNoCSDGTK4Content(GTKNoCSDWindowGetChild(CheckedWindow));
			if (Content != NULL && GTKNoCSDAdwDialog((GObject *) Content)) {
				Dialog = (AdwDialog *) Content;
			}
		}
		++Index;
	}

	return Dialog;
}

AdwDialog *adw_application_window_get_visible_dialog(
	AdwApplicationWindow *Window) {
	// Applications might expect dialogs to be returned here, but popped out
	// ones are not added. First it is checked and returned if something did add
	// a dialog, otherwise the last dialog belonging to this window is returned

	GTKNoCSDGetReferences(true);

	AdwDialog *Dialog = o_adw_application_window_get_visible_dialog(Window);
	if (Dialog != NULL) {
		return Dialog;
	}
	return GTKNoCSDAdwDialogForWindow((GtkWindow *) Window);
}

AdwDialog *adw_window_get_visible_dialog(AdwWindow *Window) {
	// Applications might expect dialogs to be returned here, but popped out
	// ones are not added. First it is checked and returned if something did add
	// a dialog, otherwise the last dialog belonging to this window is returned

	GTKNoCSDGetReferences(true);

	AdwDialog *Dialog = o_adw_window_get_visible_dialog(Window);
	if (Dialog != NULL) {
		return Dialog;
	}
	return GTKNoCSDAdwDialogForWindow((GtkWindow *) Window);
}

void GTKNoCSDUnsetDialogWindow(GtkWindow *Window) {
	// Unset a dialog window from the window list as if it was closed

	int Index = 0;
	while (GTKNoCSDWindowList[Index] != NULL) {
		if (Window == GTKNoCSDWindowList[Index][0]) {
			GTKNoCSDWindowList[Index][0] = NULL;
			break;
		}
		++Index;
	}
}

gboolean adw_dialog_close(AdwDialog *Dialog) {
	// It is possible that thanks to a race condition a closed dialogs window
	// will survive long enough that next time the application wants to close a
	// dialog, it will try to close the previous. This prevents that

	GTKNoCSDGetReferences(true);

	// Get window window of dialog
	GtkWindow *Window = (GtkWindow *) o_gtk_widget_get_ancestor(
		(GtkWidget *) Dialog, GTKNoCSDGTKWindow);

	// Try to close
	bool Success = o_adw_dialog_close(Dialog);

	// Remove from list if needed
	if (Success && Window != NULL) {
		GTKNoCSDUnsetDialogWindow(Window);
	}

	return Success;
}

void adw_dialog_force_close(AdwDialog *Dialog) {
	// It is possible that thanks to a race condition a closed dialogs window
	// will survive long enough that next time the application wants to close a
	// dialog, it will try to close the previous. This prevents that

	GTKNoCSDGetReferences(true);

	// Get window window of dialog
	GtkWindow *Window = (GtkWindow *) o_gtk_widget_get_ancestor(
		(GtkWidget *) Dialog, GTKNoCSDGTKWindow);

	// Try to close
	o_adw_dialog_force_close(Dialog);

	// Remove from list if needed
	if (Window != NULL) {
		GTKNoCSDUnsetDialogWindow(Window);
	}
}

GtkWidget *gtk_about_dialog_new(void) {
	// Entry point used by certain apps to create an about dialog.
	// Hook it, execute the original then our own function

	GTKNoCSDGetReferences(true);

	// No change in GTK2
	if (GTKNoCSDGTKVersion < 3) {
		return o_gtk_about_dialog_new();
	}

	GtkWidget *Window = o_gtk_about_dialog_new();
	GTKNoCSDMagic((GtkWindow *) Window, 0);
	return Window;
}

void gtk_show_about_dialog(GtkWindow *Window, const char *FirstProperty, ...) {
	// Entry point used by certain apps to create an about dialog.
	// Hook it, reimplement then use our own function

	// Create dialog, this is where the CSD is removed
	// WARNING: Own call
	GtkWidget *Dialog = gtk_about_dialog_new();

	// Somehow without this the next time it will not have a titlebar
	if (GTKNoCSDGTKVersion == 4) {
		o_gtk_window_set_hide_on_close((GtkWindow *) Dialog, TRUE);
	}

	// GTK3 specific close button signal
	if (GTKNoCSDGTKVersion == 3) {
		// WARNING: Macro
		g_signal_connect(Dialog, "response", G_CALLBACK(GTKNoCSDAboutClose),
			NULL);
	}

	// Do what GTK does, except no caching of the dialog
	va_list VarArgs;
	va_start(VarArgs, FirstProperty);
	o_g_object_set_valist((GObject *) Dialog, FirstProperty, VarArgs);
	va_end(VarArgs);
	if (Window) {
		o_gtk_window_set_modal((GtkWindow *) Dialog, TRUE);
		o_gtk_window_set_transient_for((GtkWindow *) Dialog, Window);
		o_gtk_window_set_destroy_with_parent((GtkWindow *) Dialog, TRUE);
	}

	// Display dialog, no need to remove CSD again
	o_gtk_window_present((GtkWindow *) Dialog);
}

// True when the first GTK GObject is loaded
bool GTKNoCSDGTKGObject = false;

void GTKNoCSDHeaderBarParent(GtkWidget *Widget, G_GNUC_UNUSED GParamSpec *Spec,
	G_GNUC_UNUSED gpointer Data) {
	// GTK displays a CSD HeaderBar when the wayland compositor does not support
	// SSD (or the KDE protocol for it) and the application does not set a CSD
	// either. Depending on user preference this is either hidden or kept

	// Only activate on the specific widget we need, hide it
	GtkWidget *Parent = o_gtk_widget_get_parent(Widget);
	if (!GTKNoCSDCSD && GTKNoCSDGtkWindow((GObject *) Parent) &&
		GTKNoCSDHasClass(Widget, "default-decoration")) {
		GTKNoCSDGTK3SetForceInvisible(Widget);
	}
}

gpointer g_object_new(GType Type, const gchar *FirstProperty, ...) {
	// Entry point used by python to create objects.
	// Hook it, reimplement then use our own function

	GTKNoCSDGetReferences(true);

	// Do what GTK does
	GObject *Object;
	if (!FirstProperty) {
		Object = o_g_object_new_with_properties(Type, 0, NULL, NULL);
	} else {
		va_list VarArgs;
		va_start(VarArgs, FirstProperty);
		Object = o_g_object_new_valist(Type, FirstProperty, VarArgs);
		va_end(VarArgs);
	}

	if (Type != 0 && GTKNoCSDGTKGObject && 2 < GTKNoCSDGTKVersion) {
		// Call our function when the object is a window
		if (GTKNoCSDGtkWindow(Object)) {
			GTKNoCSDMagic((GtkWindow *) Object, 1);
		}

		// If widget is label, set up monitor for the content
		if (GTKNoCSDGtkLabel(Object) && o_g_signal_handler_find(Object,
			G_SIGNAL_MATCH_FUNC, 0, 0, NULL, (GCallback *) GTKNoCSDTitleChanged,
			NULL) == 0) {
			// WARNING: Macro
			g_signal_connect(Object, "notify::label",
				G_CALLBACK(GTKNoCSDTitleChanged), NULL);
			GTKNoCSDTitleChanged((GtkLabel *) Object, NULL, NULL);
		}

		// This is for compositors that do not support the KDE decoration
		// protocol, but also do not want CSD
		if (GTKNoCSDGtkHeaderBar(Object)) {
			// WARNING: Macro
			g_signal_connect(Object, "notify::parent",
				G_CALLBACK(GTKNoCSDHeaderBarParent), NULL);
		}
	}

	// This is as early as possible to catch all windows with the hook
	if (GTKNoCSDGTKGObject) {
		GTKNoCSDHooker();
	}

	// Python/JS fix, as they create GObjects before loading in GTK, not in GTK2
	if (!GTKNoCSDGTKGObject && 2 < GTKNoCSDGTKVersion) {
		const char *Name = o_g_type_name(Type);
		if (strncmp(Name, "Gtk", 3) == 0) {
			GTKNoCSDGTKGObject = true;
		}
	}

	return Object;
}

void gtk_container_propagate_draw(GtkWidget *Container, GtkWidget *Child,
	cairo_t *Cairo) {
	// For LibHandy propagating to the fake header is disallowed

	GTKNoCSDGetReferences(true);

	if (Child == o_g_object_get_data((GObject *) Container,
		"GTKNoCSDTitleBar")) {
		return;
	}

	o_gtk_container_propagate_draw(Container, Child, Cairo);
}

void gtk_widget_show_all(GtkWidget *Widget) {
	// GTK3 function to display a widget. Certain apps use it to display the
	// window. Hook it, execute our own function then the original

	GTKNoCSDGetReferences(true);

	// Not in GTK2
	if (2 < GTKNoCSDGTKVersion) {
		GtkWidget *Window = GTKNoCSDGetWindow(Widget);
		if (Window != NULL) {
			GtkWidget *WindowChild =
				GTKNoCSDWindowGetChild((GtkWindow *) Window);
			if (!GTKNoCSDTest(WindowChild)) {
				GTKNoCSDMagic((GtkWindow *) Window, 0);
			}
		}
	}

	o_gtk_widget_show_all(Widget);
}

// Regex to remove CSD property from builder XML, it lives forever
GRegex *GTKNoCSDRegex = NULL;

// Builder files can specify to ignore the header preference. All builder
// creator functions are redefined and a regex disables the CSD property.
// Later, if needed, add objects functions can be implemented too
// TODO: Test whether the slightly different signatures cause an issue for GTK3
gboolean gtk_builder_add_from_string(GtkBuilder *Builder, const char *String,
	gssize Length, GError **Error) {
	// Load into builder from a string. This is where all functions end up

	GTKNoCSDGetReferences(true);

	// Try to load regex once
	if (GTKNoCSDRegex == NULL) {
		GTKNoCSDRegex = o_g_regex_new(
			"<property\\s+name=[\"']use[-_]header[-_]bar[\"']\\s*>"
			"\\s*1\\s*"
			"</property>",
			G_REGEX_OPTIMIZE | G_REGEX_MULTILINE, 0, NULL);
	}

	// If still not loaded, it failed, give back XML as is
	if (GTKNoCSDRegex == NULL) {
		return o_gtk_builder_add_from_string(Builder, String, Length, Error);
	}

	// Replace properties with disabled version, return builder with new string
	gchar *Replaced = o_g_regex_replace(GTKNoCSDRegex, String, Length, 0,
			"<property name=\"use-header-bar\">0</property>", 0, NULL);

	gboolean ReturnValue =
		o_gtk_builder_add_from_string(Builder, Replaced, -1, Error);
	o_g_free(Replaced);
	return ReturnValue;
}

GtkBuilder *gtk_builder_new_from_string(const gchar *String, gssize Length) {
	// Create a builder from a string

	GTKNoCSDGetReferences(true);

	GtkBuilder *Builder = o_gtk_builder_new();

	// WARNING: Own call
	gtk_builder_add_from_string(Builder, String, Length, NULL);

	return Builder;
}

gboolean gtk_builder_add_from_resource(GtkBuilder *Builder, const char *Path,
	GError **Error) {
	// Load into builder from resource

	GTKNoCSDGetReferences(true);

	GError *TemporaryError = NULL;

	// WARNING: Macro
	g_return_val_if_fail(GTKNoCSDGtkBuilder((GObject *) Builder), 0);
	g_return_val_if_fail(Path != NULL, 0);
	g_return_val_if_fail(Error == NULL || *Error == NULL, 0);

	GBytes *Bytes = o_g_resources_lookup_data(Path, 0, &TemporaryError);
	if (Bytes == NULL) {
		o_g_propagate_error(Error, TemporaryError);
		return FALSE;
	}

	o_g_bytes_get_data(Bytes, NULL);
	if (Bytes == NULL) {
		return FALSE;
	}

	gsize Length;
	const gchar *Data = o_g_bytes_get_data(Bytes, &Length);

	// WARNING: Own call
	// WARNING: Downcast
	gtk_builder_add_from_string(Builder, Data, (gssize) Length,
		&TemporaryError);

	o_g_bytes_unref(Bytes);

	if (TemporaryError != NULL) {
		o_g_propagate_error(Error, TemporaryError);
		return FALSE;
	}

	return TRUE;
}

GtkBuilder *gtk_builder_new_from_resource(const char *Path) {
	// Create builder from resource

	GTKNoCSDGetReferences(true);

	GError *Error = NULL;

	GtkBuilder *Builder = o_gtk_builder_new();

	// WARNING: Own call
	if (!gtk_builder_add_from_resource(Builder, Path, &Error)) {
		// WARNING: Macro
		g_error("Failed to add UI from resource %s: %s", Path, Error->message);
	}

	return Builder;
}

gboolean gtk_builder_add_from_file(GtkBuilder *Builder, const char *File,
	GError **Error) {
	// Load into builder from file

	GTKNoCSDGetReferences(true);

	char *String;
	gsize Length;
	GError *TemporaryError = NULL;

	// WARNING: Macro
	g_return_val_if_fail(GTKNoCSDGtkBuilder((GObject *) Builder), 0);
	g_return_val_if_fail(File != NULL, 0);
	g_return_val_if_fail(Error == NULL || *Error == NULL, 0);

	if (!o_g_file_get_contents(File, &String, &Length, &TemporaryError)) {
		o_g_propagate_error(Error, TemporaryError);
		return FALSE;
	}

	// Relative paths do not work when loading as string. This is where all
	// files get processed, so we save current path, get the base path of the
	// file and enter it
	char *NewPath = NULL;
	gchar *OldPath = NULL;
	const char *Slash = strrchr(File, '/');
	if (Slash != NULL) {
		// WARNING: Downcast
		NewPath = malloc((size_t) (Slash - File + 1));
		if (NewPath != NULL) {
			OldPath = o_g_get_current_dir();

			// WARNING: Downcast
			memcpy(NewPath, File, (size_t) (Slash - File + 1));
			NewPath[Slash - File] = '\0';
			G_GNUC_UNUSED int Ignore = chdir(NewPath);
		}
	}

	// WARNING: Own call
	// WARNING: Downcast
	gboolean ReturnValue =
		gtk_builder_add_from_string(Builder, String, (gssize) Length, Error);
	o_g_free(String);

	// We go back to the original path, in case anything depends on it, and free
	// memory
	G_GNUC_UNUSED int Ignore = chdir(OldPath);
	o_g_free(OldPath);
	free(NewPath);

	return ReturnValue;
}

GtkBuilder *gtk_builder_new_from_file(const gchar *FilePath) {
	// Create builder from file

	GTKNoCSDGetReferences(true);

	GError *Error = NULL;

	GtkBuilder *Builder = o_gtk_builder_new();

	// WARNING: Own call
	if (!gtk_builder_add_from_file(Builder, FilePath, &Error)) {
		// WARNING: Macro
		g_error("Failed to add UI from file %s: %s", FilePath, Error->message);
	}

	return Builder;
}

void gdk_window_get_frame_extents(void *Window, GdkRectangle *Rectangle) {
	// Some windows that had CSD might ask for the entire region, expecting the
	// region with CSD. If this is detected, only the window content is provided
	// This only applies to windows that were also undecorated

	GTKNoCSDGetReferences(true);

	// Check if window CSD got removed and the window was undecorated
	gpointer Data = NULL;
	o_gdk_window_get_user_data(Window, &Data);
	if (GTKNoCSDUndecoratedWindowList != NULL && GTKNoCSDGtkWindow(Data)) {
		int Index = 0;
		while (GTKNoCSDUndecoratedWindowList[Index] != NULL) {
			if (GTKNoCSDUndecoratedWindowList[Index] == Data) {
				Index = -1;
				break;
			}
			++Index;
		}

		if (Index == -1) {
			// If so, only fetch the size of the window content
			o_gdk_window_get_geometry(Window, &Rectangle->x, &Rectangle->y,
				&Rectangle->width, &Rectangle->height);
			return;
		}
	}

	// Do original size fetching
	o_gdk_window_get_frame_extents(Window, Rectangle);
}

void gtk_im_context_set_cursor_location(GtkIMContext *Context,
	const GdkRectangle *Area) {
	// Firefox does not reset the input method window after it was forcefully
	// transformed. Here it is set to the correct one so the input method popup
	// appears where it should

	GTKNoCSDGetReferences(true);

	// Only needed in GTK3
	if (GTKNoCSDGTKVersion == 3 && GTKNoCSDWindowList != NULL) {
		// Go through all windows
		int Index = 0;
		while (GTKNoCSDWindowList[Index] != NULL) {
			// Check if the window still exists and is the active window
			GtkWindow *Window = GTKNoCSDWindowList[Index][0];
			if (Window != NULL && o_gtk_window_is_active(Window)) {
				// Check if window has MozContainer, the Firefox webview widget
				GtkWidget *Child = GTKNoCSDWindowGetChild(Window);

				// WARNING: Macro
				if (Child != NULL && strcmp("MozContainer",
					o_g_type_name(G_OBJECT_TYPE(Child))) == 0) {
					// Set the GDKWindow as the input method window
					void *Data = o_gtk_widget_get_window(Child);
					o_gtk_im_context_set_client_window(Context, Data);
				}
				break;
			}
			++Index;
		}
	}

	o_gtk_im_context_set_cursor_location(Context, Area);
}

GType g_type_register_static(GType Parent, const gchar *Name,
	const GTypeInfo *Information, GTypeFlags Flags) {
	// Type registration might break when new GTK-NoCSD version is loaded into
	// old GTK versions. This works around that

	GTKNoCSDGetReferences(false);

	// Try to fetch existing type first
	GType Existing = o_g_type_from_name(Name);
	if (Existing != 0) {
		return Existing;
	}

	// Return new type
	return o_g_type_register_static(Parent, Name, Information, Flags);
}

GType g_type_register_static_simple(GType Parent, const gchar *Name,
	guint ClassSize, GClassInitFunc ClassInit, guint InstanceSize,
	GInstanceInitFunc InstanceInit, GTypeFlags Flags) {
	// Type registration might break when new GTK-NoCSD version is loaded into
	// old GTK versions. This works around that

	GTKNoCSDGetReferences(false);

	// Try to fetch existing type first
	GType Existing = o_g_type_from_name(Name);
	if (Existing != 0) {
		return Existing;
	}

	// Return new type
	return o_g_type_register_static_simple(Parent, Name, ClassSize, ClassInit,
			   InstanceSize, InstanceInit, Flags);
}

// Macros for simplifying getting the correct function
#define GET_SYMBOL1(Function)						  \
		if (strcmp(Name, #Function) == 0) {			  \
			typeof(Function) * Pointer = &Function;	  \
			memcpy(Symbol, &Pointer, sizeof Pointer); \
			return true;							  \
		}											  \

#define GET_SYMBOL2(Function)				\
		if (strcmp(Name, #Function) == 0) {	\
			return Function;				\
		}									\

gboolean g_module_symbol(GModule *Module, const gchar *Name, gpointer *Symbol) {
	// Python and other dynamic loading languages use this to load functions.
	// Hook it and overwrite requested functions with ours.

	GTKNoCSDGetReferences(true);

	// If platform library was not found but symbols are requested from them,
	// there is a chance of getting what is used by the library. After this also
	// get the used types. Used by script languages on sandboxed systems (Nix)
	if (!GTKNoCSDGotPlatform) {
		if (GTKNoCSDGTKVersion == 4 && strstr(Name,
			"adw_") == Name && o_adw_window_get_type == NULL) {
			GTKNoCSDGetAdwSymbols(Module, true);
			GTKNoCSDGetAdwTypes();
			GTKNoCSDGotPlatform = true;
		} else if (GTKNoCSDGTKVersion == 3 && strstr(Name,
			"hdy_") == Name && o_hdy_window_get_type == NULL) {
			GTKNoCSDGetHdySymbols(Module, true);
			GTKNoCSDGetHdyTypes();
			GTKNoCSDGotPlatform = true;
		}
	}

	if (2 < GTKNoCSDGTKVersion) {
		if (strncmp(Name, "gtk_", 4) == 0) {
			GET_SYMBOL1(gtk_window_present);
			GET_SYMBOL1(gtk_widget_set_visible);
			GET_SYMBOL1(gtk_file_chooser_get_extra_widget);
			GET_SYMBOL1(gtk_file_chooser_set_extra_widget);
			GET_SYMBOL1(gtk_container_add);
			GET_SYMBOL1(gtk_window_get_child);
			GET_SYMBOL1(gtk_window_set_child);
			GET_SYMBOL1(gtk_widget_get_parent);
			GET_SYMBOL1(gtk_widget_get_first_child);
			GET_SYMBOL1(gtk_widget_get_last_child);
			GET_SYMBOL1(gtk_window_get_titlebar);
			GET_SYMBOL1(gtk_window_set_titlebar);
			GET_SYMBOL1(gtk_header_bar_set_custom_title);
			GET_SYMBOL1(gtk_header_bar_set_title_widget);
			GET_SYMBOL1(gtk_window_set_decorated);
			GET_SYMBOL1(gtk_widget_reparent);
			GET_SYMBOL1(gtk_window_get_application);
			GET_SYMBOL1(gtk_about_dialog_new);
			GET_SYMBOL1(gtk_show_about_dialog);
			GET_SYMBOL1(gtk_container_propagate_draw);
			GET_SYMBOL1(gtk_widget_show_all);
			GET_SYMBOL1(gtk_builder_add_from_string);
			GET_SYMBOL1(gtk_builder_new_from_string);
			GET_SYMBOL1(gtk_builder_add_from_resource);
			GET_SYMBOL1(gtk_builder_new_from_resource);
			GET_SYMBOL1(gtk_builder_add_from_file);
			GET_SYMBOL1(gtk_builder_new_from_file);
			GET_SYMBOL1(gtk_im_context_set_cursor_location);
		}

		if (strncmp(Name, "adw_", 0) == 0) {
			GET_SYMBOL1(adw_header_bar_set_title_widget);
			GET_SYMBOL1(adw_dialog_present);
			GET_SYMBOL1(adw_application_window_get_visible_dialog);
			GET_SYMBOL1(adw_window_get_visible_dialog);
			GET_SYMBOL1(adw_dialog_close);
			GET_SYMBOL1(adw_dialog_force_close);
		}

		if (strncmp(Name, "g_", 2) == 0) {
			GET_SYMBOL1(g_object_new);
			GET_SYMBOL1(g_type_register_static);
			GET_SYMBOL1(g_type_register_static_simple);
			GET_SYMBOL1(g_module_symbol);
		}

		GET_SYMBOL1(gdk_window_get_frame_extents);
		GET_SYMBOL1(hdy_header_bar_set_custom_title);
	}

	return o_g_module_symbol(Module, Name, Symbol);
}

void *dlsym(void *Handle, const char *Name) {
	// Dlsym is used by Gir.Core to get functions. They are also overwritten

	GTKNoCSDInitDLSym(false);

	if (strncmp(Name, "gtk_", 4) == 0) {
		GET_SYMBOL2(gtk_window_present);
		GET_SYMBOL2(gtk_widget_set_visible);
		GET_SYMBOL2(gtk_file_chooser_get_extra_widget);
		GET_SYMBOL2(gtk_file_chooser_set_extra_widget);
		GET_SYMBOL2(gtk_container_add);
		GET_SYMBOL2(gtk_window_get_child);
		GET_SYMBOL2(gtk_window_set_child);
		GET_SYMBOL2(gtk_widget_get_parent);
		GET_SYMBOL2(gtk_widget_get_first_child);
		GET_SYMBOL2(gtk_widget_get_last_child);
		GET_SYMBOL2(gtk_window_get_titlebar);
		GET_SYMBOL2(gtk_window_set_titlebar);
		GET_SYMBOL2(gtk_header_bar_set_custom_title);
		GET_SYMBOL2(gtk_header_bar_set_title_widget);
		GET_SYMBOL2(gtk_window_set_decorated);
		GET_SYMBOL2(gtk_widget_reparent);
		GET_SYMBOL2(gtk_window_get_application);
		GET_SYMBOL2(gtk_about_dialog_new);
		GET_SYMBOL2(gtk_show_about_dialog);
		GET_SYMBOL2(gtk_container_propagate_draw);
		GET_SYMBOL2(gtk_widget_show_all);
		GET_SYMBOL2(gtk_builder_add_from_string);
		GET_SYMBOL2(gtk_builder_new_from_string);
		GET_SYMBOL2(gtk_builder_add_from_resource);
		GET_SYMBOL2(gtk_builder_new_from_resource);
		GET_SYMBOL2(gtk_builder_add_from_file);
		GET_SYMBOL2(gtk_builder_new_from_file);
		GET_SYMBOL2(gtk_im_context_set_cursor_location);
	}

	if (strncmp(Name, "adw_", 0) == 0) {
		GET_SYMBOL2(adw_header_bar_set_title_widget);
		GET_SYMBOL2(adw_dialog_present);
		GET_SYMBOL2(adw_application_window_get_visible_dialog);
		GET_SYMBOL2(adw_window_get_visible_dialog);
		GET_SYMBOL2(adw_dialog_close);
		GET_SYMBOL2(adw_dialog_force_close);
	}

	if (strncmp(Name, "g_", 2) == 0) {
		GET_SYMBOL2(g_object_new);
		GET_SYMBOL2(g_type_register_static);
		GET_SYMBOL2(g_type_register_static_simple);
		GET_SYMBOL2(g_module_symbol);
	}

	GET_SYMBOL2(gdk_window_get_frame_extents);
	GET_SYMBOL2(hdy_header_bar_set_custom_title);

	return o_dlsym(Handle, Name);
}
