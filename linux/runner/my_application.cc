#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <gtk-layer-shell.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;
  FlMethodChannel* window_channel;
  gboolean pet_mode;
  // Última zona de clics que mandó Dart (al inicio, vacía: nada recibe clics).
  cairo_region_t* input_region;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// ── Modo mascota ───────────────────────────────────────────────────────────
// Con --pet, la ventana es una capa transparente (gtk-layer-shell) que cubre
// el área útil de la pantalla. Solo Laika y sus mensajes reciben clics: Dart
// manda esas zonas con "setInputRegion"; el resto de la pantalla sigue
// funcionando normal debajo.

// LAIKA_DEBUG=1: registra en stderr las zonas que reciben clics y cada clic que
// llega a la ventana (para depurar el modo mascota).
static gboolean laika_debug() {
  static int on = -1;
  if (on < 0) on = g_getenv("LAIKA_DEBUG") != nullptr;
  return on;
}

static void debug_event_handler(GdkEvent* event, gpointer data) {
  if (event->type == GDK_BUTTON_PRESS || event->type == GDK_BUTTON_RELEASE) {
    g_printerr("[laika] gdk %s button=%u at %.0f,%.0f\n", event->type == GDK_BUTTON_PRESS ? "press" : "release",
               event->button.button, event->button.x_root, event->button.y_root);
  } else if (event->type == GDK_ENTER_NOTIFY) {
    g_printerr("[laika] gdk enter at %.0f,%.0f\n", event->crossing.x_root, event->crossing.y_root);
  }
  gtk_main_do_event(event);
}

// Se la damos a GTK a nivel widget (no gdk_window_*): así GTK la respeta cuando
// él mismo vuelve a poner la forma de la ventana (al crearla y al cambiar de
// tamaño). Antes, justo después de "realize", GTK la borraba y toda la pantalla
// recibía clics hasta que Dart mandaba la primera zona.
static void apply_input_region(MyApplication* self) {
  if (self->window == nullptr || self->input_region == nullptr) return;
  gtk_widget_input_shape_combine_region(GTK_WIDGET(self->window), self->input_region);
}

static void set_input_region(MyApplication* self, FlValue* rects) {
  cairo_region_t* region = cairo_region_create();
  if (rects != nullptr && fl_value_get_type(rects) == FL_VALUE_TYPE_LIST) {
    for (size_t i = 0; i < fl_value_get_length(rects); i++) {
      FlValue* r = fl_value_get_list_value(rects, i);
      if (fl_value_get_type(r) != FL_VALUE_TYPE_LIST || fl_value_get_length(r) != 4) continue;
      cairo_rectangle_int_t rect = {
          (int)fl_value_get_float(fl_value_get_list_value(r, 0)),
          (int)fl_value_get_float(fl_value_get_list_value(r, 1)),
          (int)fl_value_get_float(fl_value_get_list_value(r, 2)) + 1,
          (int)fl_value_get_float(fl_value_get_list_value(r, 3)) + 1,
      };
      cairo_region_union_rectangle(region, &rect);
    }
  }
  if (laika_debug()) {
    for (int i = 0; i < cairo_region_num_rectangles(region); i++) {
      cairo_rectangle_int_t r;
      cairo_region_get_rectangle(region, i, &r);
      g_printerr("[laika] input region %d: %d,%d %dx%d\n", i, r.x, r.y, r.width, r.height);
    }
    if (cairo_region_is_empty(region)) g_printerr("[laika] input region: (vacía)\n");
  }
  g_clear_pointer(&self->input_region, cairo_region_destroy);
  self->input_region = region;
  apply_input_region(self);
}

static void window_method_cb(FlMethodChannel* channel, FlMethodCall* call, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(call);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(method, "setInputRegion") == 0) {
    set_input_region(self, fl_method_call_get_args(call));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));
  } else if (g_strcmp0(method, "isPetMode") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(self->pet_mode)));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(call, response, nullptr);
}

static gboolean has_arg(char** args, const char* arg) {
  if (args == nullptr) return FALSE;
  for (char** a = args; *a != nullptr; a++) {
    if (g_strcmp0(*a, arg) == 0) return TRUE;
  }
  return FALSE;
}

static void setup_pet_window(GtkWindow* window) {
  gtk_layer_init_for_window(window);
  gtk_layer_set_namespace(window, "laika-pet");
  gtk_layer_set_layer(window, GTK_LAYER_SHELL_LAYER_TOP);
  // Cubre el área útil (respeta los paneles de KDE).
  gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_LEFT, TRUE);
  gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
  gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_TOP, TRUE);
  gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
  gtk_layer_set_exclusive_zone(window, 0);
  // El teclado solo se usa cuando haces clic en la caja de texto.
  gtk_layer_set_keyboard_mode(window, GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND);
  // Fondo transparente.
  GdkScreen* screen = gtk_window_get_screen(window);
  GdkVisual* visual = gdk_screen_get_rgba_visual(screen);
  if (visual != nullptr) gtk_widget_set_visual(GTK_WIDGET(window), visual);
  gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);
}

// Cuando la pantalla desaparece y vuelve (suspender, apagar el monitor, conectar
// otro), gtk-layer-shell esconde y vuelve a mostrar la ventana. GTK crea entonces
// una wl_surface nueva y NO le vuelve a mandar la zona de clics (cree que ya la
// mandó), así que la capa entera, que cubre la pantalla, se tragaba todos los
// clics hasta que movías a Laika. Por eso la reaplicamos cada vez que se muestra.
static void pet_window_mapped(GtkWidget* widget, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  static gboolean first = TRUE;
  if (!first) g_printerr("[laika] la ventana se volvió a mostrar (cambió la pantalla): zona de clics reaplicada\n");
  first = FALSE;
  apply_input_region(self);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;
  self->pet_mode = has_arg(self->dart_entrypoint_arguments, "--pet") && gtk_layer_is_supported();

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = !self->pet_mode;
  if (self->pet_mode) {
    if (laika_debug()) gdk_event_handler_set(debug_event_handler, nullptr, nullptr);
    setup_pet_window(window);
    // Hasta que Dart diga dónde está Laika, nada recibe clics.
    self->input_region = cairo_region_create();
    apply_input_region(self);
    g_signal_connect_after(window, "map", G_CALLBACK(pet_window_mapped), self);
  }
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (self->pet_mode) {
    gtk_window_set_title(window, "Laika");
  } else if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Laika");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Laika");
  }

  gtk_window_set_default_size(window, 1280, 800);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, self->pet_mode ? "rgba(0,0,0,0)" : "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Canal para que Dart controle la ventana (zonas que reciben clics).
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlEngine* engine = fl_view_get_engine(view);
  self->window_channel = fl_method_channel_new(fl_engine_get_binary_messenger(engine), "laika/window",
                                               FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->window_channel, window_method_cb, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->window_channel);
  g_clear_pointer(&self->input_region, cairo_region_destroy);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
