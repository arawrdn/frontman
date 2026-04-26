<?php
/**
 * Elementor data helpers used by Frontman Elementor tools.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

class Frontman_Elementor_Data {
    public static function post_uses_elementor( int $post_id ): bool {
        if ( 'builder' === get_post_meta( $post_id, '_elementor_edit_mode', true ) ) {
            return true;
        }

        return ! empty( get_post_meta( $post_id, '_elementor_data', true ) );
    }

    public static function get_page_data( int $post_id ): ?array {
        $plugin = self::elementor_plugin();
        if ( $plugin && isset( $plugin->documents ) ) {
            $document = $plugin->documents->get( $post_id );
            if ( $document && method_exists( $document, 'get_elements_data' ) ) {
                $data = $document->get_elements_data();
                if ( is_array( $data ) && ! empty( $data ) ) {
                    return $data;
                }
            }
        }

        $raw = get_post_meta( $post_id, '_elementor_data', true );
        if ( empty( $raw ) ) {
            return null;
        }
        if ( is_array( $raw ) ) {
            return $raw;
        }
        if ( ! is_string( $raw ) ) {
            return null;
        }

        $decoded = json_decode( $raw, true );
        if ( is_array( $decoded ) ) {
            return $decoded;
        }
        if ( function_exists( 'wp_unslash' ) ) {
            $decoded = json_decode( wp_unslash( $raw ), true );
            if ( is_array( $decoded ) ) {
                return $decoded;
            }
        }

        return null;
    }

    public static function save_page_data( int $post_id, array $data ): bool {
        $post = get_post( $post_id );
        if ( ! $post ) {
            throw new \RuntimeException( 'Post not found: ' . $post_id );
        }

        update_post_meta( $post_id, '_elementor_edit_mode', 'builder' );
        update_post_meta( $post_id, '_elementor_template_type', self::template_type_for_post( $post ) );
        if ( 'page' === $post->post_type ) {
            update_post_meta( $post_id, '_wp_page_template', 'elementor_header_footer' );
        }

        $plugin = self::elementor_plugin();
        if ( $plugin && isset( $plugin->documents ) ) {
            $document = $plugin->documents->get( $post_id );
            if ( $document && method_exists( $document, 'save' ) ) {
                $document->save( [ 'elements' => $data ] );
                self::flush_css( $post_id );
                return true;
            }
        }

        $json = wp_json_encode( $data );
        if ( ! is_string( $json ) || '' === $json ) {
            throw new \RuntimeException( 'Failed to encode Elementor data.' );
        }

        update_post_meta( $post_id, '_elementor_data', function_exists( 'wp_slash' ) ? wp_slash( $json ) : addslashes( $json ) );
        update_post_meta( $post_id, '_elementor_version', defined( 'ELEMENTOR_VERSION' ) ? ELEMENTOR_VERSION : 'unknown' );
        self::flush_css( $post_id );

        return true;
    }

    public static function get_page_structure( int $post_id ): ?array {
        $data = self::get_page_data( $post_id );
        return null === $data ? null : array_map( [ self::class, 'summarize_element' ], $data );
    }

    public static function get_element( array $elements, string $element_id ): ?array {
        foreach ( $elements as $element ) {
            if ( (string) ( $element['id'] ?? '' ) === $element_id ) {
                return $element;
            }
            if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) ) {
                $found = self::get_element( $element['elements'], $element_id );
                if ( null !== $found ) {
                    return $found;
                }
            }
        }

        return null;
    }

    public static function update_element_settings( array &$elements, string $element_id, array $settings ): bool {
        foreach ( $elements as &$element ) {
            if ( (string) ( $element['id'] ?? '' ) === $element_id ) {
                $current             = isset( $element['settings'] ) && is_array( $element['settings'] ) ? $element['settings'] : [];
                $element['settings'] = array_merge( $current, $settings );
                return true;
            }
            if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) && self::update_element_settings( $element['elements'], $element_id, $settings ) ) {
                return true;
            }
        }

        return false;
    }

    public static function insert_element( array &$elements, array $new_element, ?string $parent_id, int $position = -1 ): bool {
        $new_element = self::normalize_element( $new_element );
        if ( null === $parent_id || '' === $parent_id ) {
            self::insert_at_position( $elements, $new_element, $position );
            return true;
        }

        foreach ( $elements as &$element ) {
            if ( (string) ( $element['id'] ?? '' ) === $parent_id ) {
                if ( ! isset( $element['elements'] ) || ! is_array( $element['elements'] ) ) {
                    $element['elements'] = [];
                }
                self::insert_at_position( $element['elements'], $new_element, $position );
                return true;
            }
            if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) && self::insert_element( $element['elements'], $new_element, $parent_id, $position ) ) {
                return true;
            }
        }

        return false;
    }

    public static function remove_element( array &$elements, string $element_id ): bool {
        foreach ( $elements as $index => &$element ) {
            if ( (string) ( $element['id'] ?? '' ) === $element_id ) {
                array_splice( $elements, $index, 1 );
                return true;
            }
            if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) && self::remove_element( $element['elements'], $element_id ) ) {
                return true;
            }
        }

        return false;
    }

    public static function duplicate_element( array &$elements, string $element_id ): ?string {
        foreach ( $elements as $index => &$element ) {
            if ( (string) ( $element['id'] ?? '' ) === $element_id ) {
                $clone = $element;
                self::reassign_ids( $clone );
                array_splice( $elements, $index + 1, 0, [ $clone ] );
                return (string) $clone['id'];
            }
            if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) ) {
                $new_id = self::duplicate_element( $element['elements'], $element_id );
                if ( null !== $new_id ) {
                    return $new_id;
                }
            }
        }

        return null;
    }

    public static function move_element( array &$elements, string $element_id, ?string $parent_id, int $position = -1 ): bool {
        if ( null !== $parent_id && '' !== $parent_id && $parent_id === $element_id ) {
            return false;
        }

        $element = self::get_element( $elements, $element_id );
        if ( null === $element || ! self::remove_element( $elements, $element_id ) ) {
            return false;
        }

        return self::insert_element( $elements, $element, $parent_id, $position );
    }

    public static function generate_id(): string {
        try {
            return substr( bin2hex( random_bytes( 4 ) ), 0, 8 );
        } catch ( \Throwable $e ) {
            return substr( md5( uniqid( '', true ) ), 0, 8 );
        }
    }

    public static function generate_element( array $input ): array {
        $type     = sanitize_key( $input['type'] ?? 'widget' );
        $settings = isset( $input['settings'] ) && is_array( $input['settings'] ) ? $input['settings'] : [];
        $children = isset( $input['children'] ) && is_array( $input['children'] ) ? $input['children'] : [];

        switch ( $type ) {
            case 'container':
                return self::container( $settings, $children, ! empty( $input['is_inner'] ) );
            case 'row':
                return self::container( array_merge( [ 'content_width' => 'full', 'flex_direction' => 'row', 'flex_wrap' => 'wrap' ], $settings ), $children, true );
            case 'column':
                $width = isset( $input['width'] ) ? (float) $input['width'] : 50.0;
                return self::container(
                    array_merge(
                        [
                            'content_width'  => 'full',
                            'width'          => [ 'size' => $width, 'unit' => '%' ],
                            'width_tablet'   => [ 'size' => 100, 'unit' => '%' ],
                            'flex_direction' => 'column',
                        ],
                        $settings
                    ),
                    $children,
                    true
                );
            case 'heading':
                return self::widget( 'heading', array_merge( [ 'title' => sanitize_text_field( $input['title'] ?? '' ), 'header_size' => sanitize_key( $input['tag'] ?? 'h2' ) ], $settings ) );
            case 'text':
                return self::widget( 'text-editor', array_merge( [ 'editor' => wp_kses_post( $input['content'] ?? '' ) ], $settings ) );
            case 'image':
                $attachment_id = absint( $input['attachment_id'] ?? 0 );
                return self::widget( 'image', array_merge( [ 'image' => [ 'id' => $attachment_id, 'url' => $attachment_id ? wp_get_attachment_url( $attachment_id ) : '' ], 'image_size' => 'large' ], $settings ) );
            case 'button':
                return self::widget( 'button', array_merge( [ 'text' => sanitize_text_field( $input['button_text'] ?? 'Click' ), 'link' => [ 'url' => esc_url_raw( $input['url'] ?? '#' ) ] ], $settings ) );
            case 'widget':
                return self::widget( sanitize_key( $input['widget_type'] ?? 'heading' ), $settings );
            default:
                throw new \RuntimeException( 'Unsupported Elementor element generator type: ' . $type );
        }
    }

    public static function list_widgets(): array {
        $plugin = self::elementor_plugin();
        if ( ! $plugin || ! isset( $plugin->widgets_manager ) ) {
            return [];
        }

        $result = [];
        foreach ( $plugin->widgets_manager->get_widget_types() as $name => $widget ) {
            $result[] = [
                'name'       => (string) $name,
                'title'      => method_exists( $widget, 'get_title' ) ? $widget->get_title() : (string) $name,
                'icon'       => method_exists( $widget, 'get_icon' ) ? $widget->get_icon() : '',
                'categories' => method_exists( $widget, 'get_categories' ) ? $widget->get_categories() : [],
            ];
        }

        return $result;
    }

    public static function get_widget_schema( string $widget_name ): ?array {
        $plugin = self::elementor_plugin();
        if ( ! $plugin || ! isset( $plugin->widgets_manager ) ) {
            return null;
        }

        $widget = $plugin->widgets_manager->get_widget_types( $widget_name );
        if ( ! $widget || ! method_exists( $widget, 'get_controls' ) ) {
            return null;
        }

        $schema = [];
        foreach ( $widget->get_controls() as $id => $control ) {
            $type = $control['type'] ?? 'unknown';
            if ( 0 === strpos( (string) $id, '_' ) || in_array( $type, [ 'section', 'tab' ], true ) ) {
                continue;
            }

            $schema[ $id ] = [
                'type'    => $type,
                'label'   => $control['label'] ?? $id,
                'default' => $control['default'] ?? null,
            ];
            if ( ! empty( $control['options'] ) ) {
                $schema[ $id ]['options'] = $control['options'];
            }
        }

        return $schema;
    }

    public static function flush_css( int $post_id = 0 ): void {
        $plugin = self::elementor_plugin();
        if ( $plugin && isset( $plugin->files_manager ) && method_exists( $plugin->files_manager, 'clear_cache' ) ) {
            $plugin->files_manager->clear_cache();
        }

        if ( $post_id > 0 ) {
            delete_post_meta( $post_id, '_elementor_css' );
            $upload_dir = wp_upload_dir();
            $css_path   = trailingslashit( $upload_dir['basedir'] ?? '' ) . 'elementor/css/post-' . $post_id . '.css';
            if ( file_exists( $css_path ) ) {
                @unlink( $css_path );
            }
        }
    }

    private static function summarize_element( array $element ): array {
        $summary = [
            'id'     => (string) ( $element['id'] ?? '' ),
            'elType' => (string) ( $element['elType'] ?? '' ),
        ];
        if ( ! empty( $element['widgetType'] ) ) {
            $summary['widgetType'] = (string) $element['widgetType'];
        }
        if ( ! empty( $element['isInner'] ) ) {
            $summary['isInner'] = true;
        }

        $settings = isset( $element['settings'] ) && is_array( $element['settings'] ) ? $element['settings'] : [];
        $hint     = [];
        foreach ( [ 'title', 'editor', 'text', 'button_text', 'content_width', 'flex_direction' ] as $key ) {
            if ( empty( $settings[ $key ] ) || is_array( $settings[ $key ] ) ) {
                continue;
            }
            $value        = wp_strip_all_tags( (string) $settings[ $key ] );
            $hint[ $key ] = function_exists( 'mb_substr' ) ? mb_substr( $value, 0, 80 ) : substr( $value, 0, 80 );
        }
        if ( ! empty( $hint ) ) {
            $summary['hint'] = $hint;
        }
        if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) ) {
            $summary['children'] = array_map( [ self::class, 'summarize_element' ], $element['elements'] );
        }

        return $summary;
    }

    private static function container( array $settings = [], array $children = [], bool $is_inner = false ): array {
        return [
            'id'       => self::generate_id(),
            'elType'   => 'container',
            'isInner'  => $is_inner,
            'settings' => array_merge( [ 'content_width' => 'boxed', 'flex_direction' => 'column' ], $settings ),
            'elements' => array_values( $children ),
        ];
    }

    private static function widget( string $widget_type, array $settings = [] ): array {
        return [
            'id'         => self::generate_id(),
            'elType'     => 'widget',
            'widgetType' => $widget_type,
            'settings'   => $settings,
            'elements'   => [],
        ];
    }

    private static function normalize_element( array $element ): array {
        if ( empty( $element['id'] ) ) {
            $element['id'] = self::generate_id();
        }
        if ( ! isset( $element['elements'] ) || ! is_array( $element['elements'] ) ) {
            $element['elements'] = [];
        }
        if ( ! isset( $element['settings'] ) || ! is_array( $element['settings'] ) ) {
            $element['settings'] = [];
        }

        return $element;
    }

    private static function insert_at_position( array &$elements, array $element, int $position ): void {
        if ( $position < 0 || $position >= count( $elements ) ) {
            $elements[] = $element;
            return;
        }

        array_splice( $elements, $position, 0, [ $element ] );
    }

    private static function reassign_ids( array &$element ): void {
        $element['id'] = self::generate_id();
        if ( ! empty( $element['elements'] ) && is_array( $element['elements'] ) ) {
            foreach ( $element['elements'] as &$child ) {
                self::reassign_ids( $child );
            }
        }
    }

    private static function template_type_for_post( \WP_Post $post ): string {
        if ( 'page' === $post->post_type ) {
            return 'wp-page';
        }

        $existing = get_post_meta( $post->ID, '_elementor_template_type', true );
        return is_string( $existing ) && '' !== $existing ? $existing : $post->post_type;
    }

    private static function elementor_plugin() {
        if ( ! class_exists( '\Elementor\Plugin' ) ) {
            return null;
        }

        return \Elementor\Plugin::$instance;
    }
}
