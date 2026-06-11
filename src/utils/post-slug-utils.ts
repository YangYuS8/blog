const dateOnlySlugPattern = /^\d{8}-\d{2}$/;

export function isDateOnlyPostSlug(slug: string): boolean {
	return dateOnlySlugPattern.test(slug.trim());
}

export function getCanonicalPostPath(slug: string): string {
	return `/posts/${slug}/`;
}
