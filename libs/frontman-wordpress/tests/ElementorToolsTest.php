<?php

define( 'ABSPATH', sys_get_temp_dir() . '/frontman-wordpress-elementor-tools/' );

$GLOBALS['frontman_test_posts'] = [];
$GLOBALS['frontman_test_meta']  = [];

if ( ! class_exists( 'WP_Post' ) ) {
	class WP_Post {
		public int $ID;
		public string $post_title;
		public string $post_name;
		public string $post_status;
		public string $post_type;

		public function __construct( int $id, string $title, string $slug, string $status = 'publish', string $type = 'page' ) {
			$this->ID          = $id;
			$this->post_title  = $title;
			$this->post_name   = $slug;
			$this->post_status = $status;
			$this->post_type   = $type;
		}
	}
}

if ( ! function_exists( 'wp_json_encode' ) ) {
	function wp_json_encode( $value, int $flags = 0 ) {
		return json_encode( $value, $flags );
	}
}

if ( ! function_exists( 'wp_slash' ) ) {
	function wp_slash( $value ) {
		return is_string( $value ) ? addslashes( $value ) : $value;
	}
}

if ( ! function_exists( 'wp_unslash' ) ) {
	function wp_unslash( $value ) {
		return is_string( $value ) ? stripslashes( $value ) : $value;
	}
}

if ( ! function_exists( 'sanitize_key' ) ) {
	function sanitize_key( $value ): string {
		return strtolower( preg_replace( '/[^a-zA-Z0-9_\-]/', '', (string) $value ) );
	}
}

if ( ! function_exists( 'sanitize_text_field' ) ) {
	function sanitize_text_field( $value ): string {
		return trim( (string) $value );
	}
}

if ( ! function_exists( 'wp_kses_post' ) ) {
	function wp_kses_post( $value ): string {
		return (string) $value;
	}
}

if ( ! function_exists( 'esc_url_raw' ) ) {
	function esc_url_raw( $value ): string {
		return (string) $value;
	}
}

if ( ! function_exists( 'absint' ) ) {
	function absint( $value ): int {
		return abs( (int) $value );
	}
}

if ( ! function_exists( 'wp_strip_all_tags' ) ) {
	function wp_strip_all_tags( $value ): string {
		return strip_tags( (string) $value );
	}
}

if ( ! function_exists( 'trailingslashit' ) ) {
	function trailingslashit( string $value ): string {
		return rtrim( $value, '/\\' ) . '/';
	}
}

if ( ! function_exists( 'wp_upload_dir' ) ) {
	function wp_upload_dir(): array {
		return [ 'basedir' => sys_get_temp_dir() ];
	}
}

if ( ! function_exists( 'wp_get_attachment_url' ) ) {
	function wp_get_attachment_url( int $id ): string {
		return 'https://example.test/uploads/' . $id . '.jpg';
	}
}

if ( ! function_exists( 'get_post_meta' ) ) {
	function get_post_meta( int $post_id, string $key, bool $single = true ) {
		return $GLOBALS['frontman_test_meta'][ $post_id ][ $key ] ?? '';
	}
}

if ( ! function_exists( 'update_post_meta' ) ) {
	function update_post_meta( int $post_id, string $key, $value ): bool {
		$GLOBALS['frontman_test_meta'][ $post_id ][ $key ] = $value;
		return true;
	}
}

if ( ! function_exists( 'delete_post_meta' ) ) {
	function delete_post_meta( int $post_id, string $key ): bool {
		unset( $GLOBALS['frontman_test_meta'][ $post_id ][ $key ] );
		return true;
	}
}

if ( ! function_exists( 'get_post' ) ) {
	function get_post( int $post_id ) {
		return $GLOBALS['frontman_test_posts'][ $post_id ] ?? null;
	}
}

if ( ! function_exists( 'get_posts' ) ) {
	function get_posts( array $args ): array {
		$post_type = $args['post_type'] ?? 'page';
		return array_values( array_filter( $GLOBALS['frontman_test_posts'], function ( $post ) use ( $post_type ) { return $post->post_type === $post_type; } ) );
	}
}

if ( ! function_exists( 'get_permalink' ) ) {
	function get_permalink( int $post_id ): string {
		return 'https://example.test/page-' . $post_id;
	}
}

if ( ! function_exists( 'get_the_title' ) ) {
	function get_the_title( int $post_id ): string {
		$post = get_post( $post_id );
		return $post ? $post->post_title : '';
	}
}

require_once __DIR__ . '/../includes/class-frontman-tools.php';
require_once __DIR__ . '/../includes/class-frontman-elementor-data.php';
require_once __DIR__ . '/../tools/class-tool-elementor.php';

class Frontman_Elementor_Tools_Test_Runner {
	private Frontman_Tools $tools;
	private int $assertions = 0;

	public function __construct() {
		$this->tools = new Frontman_Tools();
		( new Frontman_Tool_Elementor() )->register( $this->tools );
	}

	public function run(): void {
		$this->seed_page();
		$this->test_tools_registered();
		$this->test_structure_and_get_element();
		$this->test_update_duplicate_and_flush();
		$this->test_generate_element();

		fwrite( STDOUT, "OK ({$this->assertions} assertions)\n" );
	}

	private function seed_page(): void {
		$GLOBALS['frontman_test_posts'][42] = new WP_Post( 42, 'Home', 'home' );
		$GLOBALS['frontman_test_meta'][42]  = [
			'_elementor_edit_mode' => 'builder',
			'_elementor_data'      => wp_json_encode(
				[
					[
						'id'       => 'root1111',
						'elType'   => 'container',
						'settings' => [ 'flex_direction' => 'column' ],
						'elements' => [
							[
								'id'         => 'head2222',
								'elType'     => 'widget',
								'widgetType' => 'heading',
								'settings'   => [ 'title' => 'Hello' ],
								'elements'   => [],
							],
						],
					],
				]
			),
		];
	}

	private function test_tools_registered(): void {
		$names = array_column( $this->tools->all_definitions(), 'name' );
		$this->assert_true( in_array( 'wp_elementor_get_page_structure', $names, true ), 'Elementor structure tool is registered' );
		$this->assert_true( in_array( 'wp_elementor_update_element', $names, true ), 'Elementor update tool is registered' );
	}

	private function test_structure_and_get_element(): void {
		$structure = $this->call_success( 'wp_elementor_get_page_structure', [ 'post_id' => 42 ] );
		$this->assert_same( 'root1111', $structure['structure'][0]['id'], 'Structure includes root element' );
		$this->assert_same( 'Hello', $structure['structure'][0]['children'][0]['hint']['title'], 'Structure includes text hints' );

		$element = $this->call_success( 'wp_elementor_get_element', [ 'post_id' => 42, 'element_id' => 'head2222' ] );
		$this->assert_same( 'heading', $element['widgetType'], 'Get element returns widget data' );
	}

	private function test_update_duplicate_and_flush(): void {
		$updated = $this->call_success( 'wp_elementor_update_element', [ 'post_id' => 42, 'element_id' => 'head2222', 'settings' => [ 'title' => 'Updated' ] ] );
		$this->assert_true( true === $updated['success'], 'Update returns success' );

		$data = Frontman_Elementor_Data::get_page_data( 42 );
		$this->assert_same( 'Updated', $data[0]['elements'][0]['settings']['title'], 'Update merges settings into Elementor data' );

		$duplicated = $this->call_success( 'wp_elementor_duplicate_element', [ 'post_id' => 42, 'element_id' => 'head2222' ] );
		$this->assert_true( ! empty( $duplicated['new_element_id'] ), 'Duplicate returns new element ID' );

		$flushed = $this->call_success( 'wp_elementor_flush_css', [ 'post_id' => 42 ] );
		$this->assert_same( 'post-42', $flushed['scope'], 'Flush reports post scope' );
	}

	private function test_generate_element(): void {
		$element = $this->call_success( 'wp_elementor_generate_element', [ 'type' => 'heading', 'title' => 'Generated', 'tag' => 'h1' ] );
		$this->assert_same( 'widget', $element['elType'], 'Generated heading is a widget' );
		$this->assert_same( 'heading', $element['widgetType'], 'Generated heading has widget type' );
		$this->assert_same( 'Generated', $element['settings']['title'], 'Generated heading uses title' );
	}

	private function call_success( string $name, array $input ): array {
		$result = $this->tools->call( $name, $input );
		if ( ! empty( $result['isError'] ) ) {
			throw new RuntimeException( 'Tool returned error: ' . $result['content'][0]['text'] );
		}

		return json_decode( $result['content'][0]['text'], true );
	}

	private function assert_same( $expected, $actual, string $message ): void {
		$this->assertions++;
		if ( $expected !== $actual ) {
			throw new RuntimeException( $message . "\nExpected: " . var_export( $expected, true ) . "\nActual: " . var_export( $actual, true ) );
		}
	}

	private function assert_true( bool $condition, string $message ): void {
		$this->assertions++;
		if ( ! $condition ) {
			throw new RuntimeException( $message );
		}
	}
}

( new Frontman_Elementor_Tools_Test_Runner() )->run();
