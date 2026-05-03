import "@typespec/json-schema";
using TypeSpec.JsonSchema;

@jsonSchema("/modules/managed-flatpaks.json")
model ManagedFlatpaksModule {
    /** The managed-flatpaks module can be used to install or uninstall flatpaks from a configurable remote on every boot.
     * using version: v1
     * https://blue-build.org/reference/modules/default-flatpaks/
     */
    type: "managed-flatpaks" | "managed-flatpaks@v1";

    configurations: Array<{
        /** Whether to notify users about Flatpak installation. */
        notify?: boolean = true;

        /** Whether to perform this configuration for system-wide or separately for each user. */
        scope?: "system" | "user" = "user";

        /** Details of the Flatpak repository to set up. If omitted, Flathub will be used by default. */
        repo?: {
            /** Flatpak repository URL. */
            url?: string = "https://dl.flathub.org/repo/flathub.flatpakrepo";

            /** Flatpak repository name. */
            name?: string = "flathub";

            /** Flatpak repository formatted title. */
            title?: string = "Flathub";
        };

        /** List of Flatpak IDs to install from the repo. */
        install?: Array<string>;

        /** List of Flatpak IDs to remove. */
        remove?: Array<string>;
    }>;
}
