shader_type canvas_item;

uniform float skew_amount : hint_range(-1.0, 1.0) = 0.0;

void vertex() {
    // Apply skew to the x position based on y
    VERTEX.x += VERTEX.y * skew_amount;
}
