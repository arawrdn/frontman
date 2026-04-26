<?php
/**
 * Elementor tools for reading and editing Elementor page data.
 *
 * @package Frontman
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// phpcs:disable WordPress.Security.EscapeOutput.ExceptionNotEscaped -- Exception messages are internal tool errors, not rendered HTML output.

class Frontman_Tool_Elementor {
	public function register( Frontman_Tools $tools ): void {
		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_list_pages',
			'Lists WordPress pages and whether each page has Elementor builder data. Use this to find the post_id for Elementor tools.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_type' => [ 'type' => 'string', 'default' => 'page' ],
					'per_page'  => [ 'type' => 'integer', 'default' => 100 ],
				],
			],
			[ $this, 'list_pages' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_get_page_structure',
			'Gets a compact Elementor page tree with element IDs, element types, widget types, and key text/style hints. Start here before editing Elementor content.',
			$this->post_id_schema(),
			[ $this, 'get_page_structure' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_get_page_data',
			'Gets the full Elementor element tree for a post. Prefer wp_elementor_get_page_structure unless you need complete settings.',
			$this->post_id_schema(),
			[ $this, 'get_page_data' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_save_page_data',
			'Replaces the full Elementor element tree for a post after saving the previous tree as a private rollback snapshot. Ask the user for confirmation first and only call with confirm=true after approval. Use granular element tools when possible; call wp_elementor_flush_css after visual changes.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id' => [ 'type' => 'integer' ],
					'data'    => [
						'type'        => 'array',
						'description' => 'Full Elementor element tree.',
						'items'       => [
							'type'                 => 'object',
							'additionalProperties' => true,
							'properties'           => new \stdClass(),
						],
					],
					'confirm' => [ 'type' => 'boolean', 'description' => 'Must be true only after the user explicitly confirms replacing the full Elementor page data.' ],
				],
				'required'             => [ 'post_id', 'data', 'confirm' ],
			],
			[ $this, 'save_page_data' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_get_element',
			'Gets one Elementor element by post_id and element_id. Selected Elementor elements include these IDs in the selected-element context.',
			$this->element_id_schema(),
			[ $this, 'get_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_update_element',
			'Updates one Elementor element settings object by merging provided settings into the existing settings after saving the previous element as a private rollback snapshot. Never send the whole page for a small widget/style edit.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'    => [ 'type' => 'integer' ],
					'element_id' => [ 'type' => 'string' ],
					'settings'   => [
						'type'                 => 'object',
						'description'          => 'Elementor settings keys to merge.',
						'additionalProperties' => true,
						'properties'           => new \stdClass(),
					],
				],
				'required'             => [ 'post_id', 'element_id', 'settings' ],
			],
			[ $this, 'update_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_add_element',
			'Adds a new Elementor element at the root or inside a parent container. Use wp_elementor_generate_element or widget schema output to build valid element JSON.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'    => [ 'type' => 'integer' ],
					'element'    => [
						'type'                 => 'object',
						'additionalProperties' => true,
						'properties'           => new \stdClass(),
					],
					'parent_id'  => [ 'type' => 'string' ],
					'position'   => [ 'type' => 'integer', 'default' => -1 ],
				],
				'required'             => [ 'post_id', 'element' ],
			],
			[ $this, 'add_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_remove_element',
			'Removes an Elementor element and its children after saving the previous element as a private rollback snapshot. Ask the user for confirmation first and only call with confirm=true after approval.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'    => [ 'type' => 'integer' ],
					'element_id' => [ 'type' => 'string' ],
					'confirm'    => [ 'type' => 'boolean' ],
				],
				'required'             => [ 'post_id', 'element_id', 'confirm' ],
			],
			[ $this, 'remove_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_list_rollbacks',
			'Lists private Elementor rollback snapshots for a post. Use this to find rollback_id values before restoring.',
			$this->post_id_schema(),
			[ $this, 'list_rollbacks' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_restore_rollback',
			'Restores a private Elementor rollback snapshot by rollback_id. Ask the user for confirmation first and only call with confirm=true after approval.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'     => [ 'type' => 'integer' ],
					'rollback_id' => [ 'type' => 'string' ],
					'confirm'     => [ 'type' => 'boolean' ],
				],
				'required'             => [ 'post_id', 'rollback_id', 'confirm' ],
			],
			[ $this, 'restore_rollback' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_duplicate_element',
			'Duplicates an Elementor element next to the original, assigning new IDs to the clone and its children.',
			$this->element_id_schema(),
			[ $this, 'duplicate_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_move_element',
			'Moves an Elementor element to the root or into another parent element at a position. position=-1 appends.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'post_id'    => [ 'type' => 'integer' ],
					'element_id' => [ 'type' => 'string' ],
					'parent_id'  => [ 'type' => 'string' ],
					'position'   => [ 'type' => 'integer', 'default' => -1 ],
				],
				'required'             => [ 'post_id', 'element_id' ],
			],
			[ $this, 'move_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_generate_element',
			'Generates a valid Elementor element JSON object. Supports container, row, column, heading, text, image, button, and generic widget.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [
					'type'          => [
						'type' => 'string',
						'enum' => [ 'container', 'row', 'column', 'heading', 'text', 'image', 'button', 'widget' ],
					],
					'settings'      => [
						'type'                 => 'object',
						'additionalProperties' => true,
						'properties'           => new \stdClass(),
					],
					'children'      => [
						'type'  => 'array',
						'items' => [
							'type'                 => 'object',
							'additionalProperties' => true,
							'properties'           => new \stdClass(),
						],
					],
					'widget_type'   => [ 'type' => 'string' ],
					'is_inner'      => [ 'type' => 'boolean', 'default' => false ],
					'width'         => [ 'type' => 'number', 'default' => 50 ],
					'title'         => [ 'type' => 'string' ],
					'tag'           => [ 'type' => 'string', 'default' => 'h2' ],
					'content'       => [ 'type' => 'string' ],
					'attachment_id' => [ 'type' => 'integer' ],
					'button_text'   => [ 'type' => 'string', 'default' => 'Click' ],
					'url'           => [ 'type' => 'string', 'default' => '#' ],
				],
				'required'             => [ 'type' ],
			],
			[ $this, 'generate_element' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_list_widgets',
			'Lists registered Elementor widgets with names, titles, icons, and categories.',
			[ 'type' => 'object', 'additionalProperties' => false, 'properties' => new \stdClass() ],
			[ $this, 'list_widgets' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_get_widget_schema',
			'Gets Elementor control schema for one widget type. Use before creating or updating unfamiliar widget settings.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [ 'widget_name' => [ 'type' => 'string' ] ],
				'required'             => [ 'widget_name' ],
			],
			[ $this, 'get_widget_schema' ]
		) );

		$tools->add( new Frontman_Tool_Definition(
			'wp_elementor_flush_css',
			'Flushes Elementor CSS cache. Call this after Elementor visual changes so the preview reflects the update.',
			[
				'type'                 => 'object',
				'additionalProperties' => false,
				'properties'           => [ 'post_id' => [ 'type' => 'integer' ] ],
			],
			[ $this, 'flush_css' ]
		) );
	}

	public function list_pages( array $input ): array {
		$post_type = sanitize_key( $input['post_type'] ?? 'page' );
		$per_page  = min( max( absint( $input['per_page'] ?? 100 ), 1 ), 200 );
		$posts     = get_posts(
			[
				'post_type'      => $post_type,
				'post_status'    => [ 'publish', 'draft', 'pending', 'private' ],
				'posts_per_page' => $per_page,
				'orderby'        => 'menu_order title',
				'order'          => 'ASC',
			]
		);

		return [
			'pages' => array_map(
				function ( $post ) {
					return [
						'post_id'       => (int) $post->ID,
						'title'         => $post->post_title,
						'slug'          => $post->post_name,
						'status'        => $post->post_status,
						'url'           => get_permalink( $post->ID ),
						'has_elementor' => Frontman_Elementor_Data::post_uses_elementor( (int) $post->ID ),
					];
				},
				$posts
			),
		];
	}

	public function get_page_structure( array $input ): array {
		$post_id   = $this->require_post_id( $input );
		$structure = Frontman_Elementor_Data::get_page_structure( $post_id );
		if ( null === $structure ) {
			throw new Frontman_Tool_Error( 'No Elementor data found for post_id ' . $post_id );
		}

		return [ 'post_id' => $post_id, 'title' => get_the_title( $post_id ), 'structure' => $structure ];
	}

	public function get_page_data( array $input ): array {
		$post_id = $this->require_post_id( $input );
		$data    = $this->require_page_data( $post_id );
		return [ 'post_id' => $post_id, 'title' => get_the_title( $post_id ), 'data' => $data ];
	}

	public function save_page_data( array $input ): array {
		if ( true !== ( $input['confirm'] ?? false ) ) {
			throw new Frontman_Tool_Error( 'Full Elementor page replacement requires confirm=true after user approval.' );
		}

		$post_id = $this->require_post_id( $input );
		$data    = $input['data'] ?? null;
		if ( ! is_array( $data ) ) {
			throw new Frontman_Tool_Error( 'data must be an Elementor element tree array.' );
		}

		$current  = Frontman_Elementor_Data::get_page_data( $post_id );
		$rollback = is_array( $current ) ? Frontman_Elementor_Data::make_page_rollback( 'saved_page_data', $current ) : null;
		if ( null !== $rollback ) {
			Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		}
		$this->save_elementor_data( $post_id, $data );

		return [ 'success' => true, 'post_id' => $post_id, 'sections' => count( $data ), 'rollback_id' => $rollback['rollback_id'] ?? null ];
	}

	public function get_element( array $input ): array {
		$post_id    = $this->require_post_id( $input );
		$element_id = $this->require_element_id( $input );
		$element    = Frontman_Elementor_Data::get_element( $this->require_page_data( $post_id ), $element_id );
		if ( null === $element ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}

		return $element;
	}

	public function update_element( array $input ): array {
		$post_id    = $this->require_post_id( $input );
		$element_id = $this->require_element_id( $input );
		$settings   = $input['settings'] ?? null;
		if ( ! is_array( $settings ) ) {
			throw new Frontman_Tool_Error( 'settings must be an object.' );
		}

		$data     = $this->require_page_data( $post_id );
		$rollback = Frontman_Elementor_Data::make_element_rollback( 'updated', $data, $element_id );
		if ( null === $rollback ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}
		if ( ! Frontman_Elementor_Data::update_element_settings( $data, $element_id, $settings ) ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}

		Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		$this->save_elementor_data( $post_id, $data );
		return [ 'success' => true, 'post_id' => $post_id, 'element_id' => $element_id, 'rollback_id' => $rollback['rollback_id'] ];
	}

	public function add_element( array $input ): array {
		$post_id = $this->require_post_id( $input );
		$element = $input['element'] ?? null;
		if ( ! is_array( $element ) ) {
			throw new Frontman_Tool_Error( 'element must be an object.' );
		}
		if ( empty( $element['id'] ) ) {
			$element['id'] = Frontman_Elementor_Data::generate_id();
		}

		$data      = Frontman_Elementor_Data::get_page_data( $post_id ) ?? [];
		$rollback  = Frontman_Elementor_Data::make_page_rollback( 'added_element', $data );
		$parent_id = isset( $input['parent_id'] ) ? sanitize_text_field( $input['parent_id'] ) : null;
		$position  = (int) ( $input['position'] ?? -1 );
		if ( ! Frontman_Elementor_Data::insert_element( $data, $element, $parent_id, $position ) ) {
			throw new Frontman_Tool_Error( 'Parent element not found: ' . $parent_id );
		}

		Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		$this->save_elementor_data( $post_id, $data );
		return [ 'success' => true, 'post_id' => $post_id, 'element_id' => $element['id'] ?? '', 'rollback_id' => $rollback['rollback_id'] ];
	}

	public function remove_element( array $input ): array {
		if ( true !== ( $input['confirm'] ?? false ) ) {
			throw new Frontman_Tool_Error( 'Element removal requires confirm=true after user approval.' );
		}

		$post_id    = $this->require_post_id( $input );
		$element_id = $this->require_element_id( $input );
		$data       = $this->require_page_data( $post_id );
		$rollback   = Frontman_Elementor_Data::make_element_rollback( 'removed', $data, $element_id );
		if ( null === $rollback ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}
		if ( ! Frontman_Elementor_Data::remove_element( $data, $element_id ) ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}

		Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		$this->save_elementor_data( $post_id, $data );
		return [ 'success' => true, 'post_id' => $post_id, 'element_id' => $element_id, 'rollback_id' => $rollback['rollback_id'] ];
	}

	public function list_rollbacks( array $input ): array {
		$post_id = $this->require_post_id( $input );
		return [ 'post_id' => $post_id, 'rollbacks' => Frontman_Elementor_Data::list_rollbacks( $post_id ) ];
	}

	public function restore_rollback( array $input ): array {
		if ( true !== ( $input['confirm'] ?? false ) ) {
			throw new Frontman_Tool_Error( 'Rollback restore requires confirm=true after user approval.' );
		}

		$post_id     = $this->require_post_id( $input );
		$rollback_id = $this->require_rollback_id( $input );
		$result      = Frontman_Elementor_Data::restore_rollback( $post_id, $rollback_id );
		if ( null === $result ) {
			throw new Frontman_Tool_Error( 'Rollback not found: ' . $rollback_id );
		}
		if ( empty( $result['success'] ) ) {
			throw new Frontman_Tool_Error( $result['error'] ?? 'Unable to restore rollback.' );
		}

		return array_merge( [ 'post_id' => $post_id ], $result );
	}

	public function duplicate_element( array $input ): array {
		$post_id    = $this->require_post_id( $input );
		$element_id = $this->require_element_id( $input );
		$data       = $this->require_page_data( $post_id );
		$rollback   = Frontman_Elementor_Data::make_page_rollback( 'duplicated_element', $data );
		$new_id     = Frontman_Elementor_Data::duplicate_element( $data, $element_id );
		if ( null === $new_id ) {
			throw new Frontman_Tool_Error( 'Element not found: ' . $element_id );
		}

		Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		$this->save_elementor_data( $post_id, $data );
		return [ 'success' => true, 'post_id' => $post_id, 'element_id' => $element_id, 'new_element_id' => $new_id, 'rollback_id' => $rollback['rollback_id'] ];
	}

	public function move_element( array $input ): array {
		$post_id    = $this->require_post_id( $input );
		$element_id = $this->require_element_id( $input );
		$parent_id  = isset( $input['parent_id'] ) ? sanitize_text_field( $input['parent_id'] ) : null;
		$position   = (int) ( $input['position'] ?? -1 );
		$data       = $this->require_page_data( $post_id );
		$rollback   = Frontman_Elementor_Data::make_page_rollback( 'moved_element', $data );
		if ( ! Frontman_Elementor_Data::move_element( $data, $element_id, $parent_id, $position ) ) {
			throw new Frontman_Tool_Error( 'Unable to move element: ' . $element_id );
		}

		Frontman_Elementor_Data::save_rollback( $post_id, $rollback );
		$this->save_elementor_data( $post_id, $data );
		return [ 'success' => true, 'post_id' => $post_id, 'element_id' => $element_id, 'parent_id' => $parent_id, 'position' => $position, 'rollback_id' => $rollback['rollback_id'] ];
	}

	public function generate_element( array $input ): array {
		return Frontman_Elementor_Data::generate_element( $input );
	}

	public function list_widgets( array $input ): array {
		return [ 'widgets' => Frontman_Elementor_Data::list_widgets() ];
	}

	public function get_widget_schema( array $input ): array {
		$widget_name = sanitize_key( $input['widget_name'] ?? '' );
		if ( '' === $widget_name ) {
			throw new Frontman_Tool_Error( 'widget_name is required.' );
		}

		$schema = Frontman_Elementor_Data::get_widget_schema( $widget_name );
		if ( null === $schema ) {
			throw new Frontman_Tool_Error( 'Widget not found or Elementor is not loaded: ' . $widget_name );
		}

		return [ 'widget_name' => $widget_name, 'schema' => $schema ];
	}

	public function flush_css( array $input ): array {
		$post_id = absint( $input['post_id'] ?? 0 );
		Frontman_Elementor_Data::flush_css( $post_id );
		return [ 'success' => true, 'scope' => $post_id > 0 ? 'post-' . $post_id : 'all' ];
	}

	private function post_id_schema(): array {
		return [
			'type'                 => 'object',
			'additionalProperties' => false,
			'properties'           => [ 'post_id' => [ 'type' => 'integer', 'description' => 'WordPress post/page ID.' ] ],
			'required'             => [ 'post_id' ],
		];
	}

	private function element_id_schema(): array {
		$schema                                  = $this->post_id_schema();
		$schema['properties']['element_id']      = [ 'type' => 'string', 'description' => 'Elementor element ID from page structure or selected-element context.' ];
		$schema['required']                      = [ 'post_id', 'element_id' ];
		return $schema;
	}

	private function require_post_id( array $input ): int {
		$post_id = absint( $input['post_id'] ?? 0 );
		if ( 0 === $post_id ) {
			throw new Frontman_Tool_Error( 'post_id is required.' );
		}

		return $post_id;
	}

	private function require_element_id( array $input ): string {
		$element_id = sanitize_text_field( $input['element_id'] ?? '' );
		if ( '' === $element_id ) {
			throw new Frontman_Tool_Error( 'element_id is required.' );
		}

		return $element_id;
	}

	private function require_rollback_id( array $input ): string {
		$rollback_id = sanitize_text_field( $input['rollback_id'] ?? '' );
		if ( '' === $rollback_id ) {
			throw new Frontman_Tool_Error( 'rollback_id is required.' );
		}

		return $rollback_id;
	}

	private function save_elementor_data( int $post_id, array $data ): void {
		try {
			Frontman_Elementor_Data::save_page_data( $post_id, $data );
		} catch ( \Throwable $e ) {
			throw new Frontman_Tool_Error( 'Failed to save Elementor data: ' . $e->getMessage() );
		}
	}

	private function require_page_data( int $post_id ): array {
		$data = Frontman_Elementor_Data::get_page_data( $post_id );
		if ( null === $data ) {
			throw new Frontman_Tool_Error( 'No Elementor data found for post_id ' . $post_id );
		}

		return $data;
	}
}
