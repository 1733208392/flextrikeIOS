# Video FAQ Template

A Shopify page template for displaying video cards in a grid layout, similar to YouTube video thumbnails.

## Features

- **Grid Layout**: Responsive grid that displays 1-4 columns on desktop and 1-2 columns on mobile
- **Video Cards**: Each card includes:
  - Thumbnail image
  - Video title
  - Duration badge
  - View count
  - Date posted
  - Optional playlist indicator
- **Clickable Cards**: Cards link directly to video URLs (YouTube, Vimeo, etc.)
- **Mobile Swipe**: Optional swipe/slider functionality on mobile devices
- **Customizable**: All content editable through Shopify customizer
- **Animations**: Smooth fade-in animations and hover effects

## Installation

The template has been installed in your theme with the following files:

1. **Template File**: `/templates/page.video-faq.json`
2. **Section File**: `/sections/video-faq.liquid`
3. **CSS File**: `/assets/section-video-faq.css`
4. **Locales**: 
   - `/locales/en.default.json` (translations)
   - `/locales/en.default.schema.json` (schema translations)

## Usage

### Creating a Video FAQ Page

1. Go to **Online Store > Pages** in your Shopify admin
2. Click **Add page**
3. Enter a page title (e.g., "Video Tutorials" or "FAQ Videos")
4. On the right sidebar, under **Theme template**, select **page.video-faq**
5. Click **Save**
6. Click **Customize** to edit the page content

### Adding the Section to Other Pages

You can also add the Video FAQ section to any page:

1. Go to **Online Store > Themes** in your Shopify admin
2. Click **Customize** on your active theme
3. Navigate to the page where you want to add the section
4. Click **Add section**
5. Select **Video FAQ** from the list
6. Configure the section settings

### Section Settings

#### General Settings
- **Heading**: Main title for the section (e.g., "Video Tutorials")
- **Subheading**: Optional descriptive text below the heading
- **Heading Size**: Choose Small, Medium, or Large
- **Color Scheme**: Select from your theme's color schemes
- **Desktop Columns**: 1-4 columns (default: 3)

#### Mobile Settings
- **Mobile Columns**: 1 or 2 columns (default: 1)
- **Enable Swipe**: Turn on slider functionality for mobile

#### Padding
- **Top Padding**: 0-100px (default: 36px)
- **Bottom Padding**: 0-100px (default: 36px)

### Adding Video Cards

1. In the section settings, click **Add block** > **Video Card**
2. Configure each card:
   - **Video Thumbnail**: Upload a custom thumbnail image
   - **Video Title**: Enter the video title (e.g., "How to Setup FlexTarget")
   - **Video URL**: Paste the full URL to your video (YouTube, Vimeo, etc.)
   - **Video Duration**: Enter duration in format "1:44" or "2:47"
   - **Show Duration Badge**: Toggle on/off
   - **View Count**: Enter view count (e.g., "17" or "1.2K")
   - **Show View Count**: Toggle on/off
   - **Date**: Enter date text (e.g., "5 days ago" or "Jan 15, 2024")
   - **Show Date**: Toggle on/off
   - **Show Playlist Indicator**: Show playlist icon (optional)

3. Repeat for additional video cards
4. Reorder cards by dragging them
5. Click **Save**

## Example Configuration

### Sample Video Card Settings

**Card 1:**
- Title: "CQB & IPSC Stage Training at Home: Build Match-Ready Skills"
- Video URL: `https://youtube.com/watch?v=...`
- Duration: `1:44`
- Views: `17`
- Date: `5 days ago`

**Card 2:**
- Title: "Can You Really Practice Home Defense at Home? (Yes — Here's How)"
- Video URL: `https://youtube.com/watch?v=...`
- Duration: `2:15`
- Views: `11`
- Date: `5 days ago`

**Card 3:**
- Title: "FlexTarget Setup Tutorial | Unboxing & Quick Start Guide"
- Video URL: `https://youtube.com/watch?v=...`
- Duration: `2:47`
- Views: `8`
- Date: `5 days ago`

## Styling

The section uses your theme's existing color schemes and follows Shopify theme conventions. The CSS includes:

- Responsive grid layout
- Hover animations on cards
- Duration badge overlay on thumbnails
- Smooth transitions
- Dark mode support (if your theme supports it)
- Accessibility features (focus states, ARIA labels)

## Customization

### Modifying Styles

Edit `/assets/section-video-faq.css` to customize:
- Card border radius
- Hover effects
- Typography
- Spacing
- Colors (beyond color schemes)
- Animation timings

### Modifying Layout

Edit `/sections/video-faq.liquid` to customize:
- Card layout structure
- Add new fields to video cards
- Change grid behavior
- Add additional elements

## Browser Support

The section is tested and compatible with:
- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)
- Mobile browsers (iOS Safari, Chrome Mobile)

## Notes

- **Video URLs**: Cards link to external video platforms. For embedded video playback within your site, consider using Shopify's video section instead.
- **Thumbnails**: Upload high-quality thumbnail images (recommended: 1280x720px or 16:9 aspect ratio)
- **Performance**: Images are automatically optimized by Shopify with responsive srcset
- **Empty State**: If no video cards are added, a helpful message appears in the customizer

## Accessibility

The section includes accessibility features:
- Semantic HTML structure
- Proper heading hierarchy
- Alt text for images
- Focus indicators for keyboard navigation
- Screen reader friendly

## Support

For customization help or issues, refer to:
- [Shopify Theme Development Documentation](https://shopify.dev/themes)
- [Liquid Template Language](https://shopify.dev/api/liquid)
