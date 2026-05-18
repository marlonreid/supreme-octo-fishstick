() => {
    let max = 0;
    document.querySelectorAll('.ide-content-section, pre').forEach(el => {
        const orig = el.style.width;
        el.style.width = 'max-content';
        const right = el.getBoundingClientRect().right + window.scrollX;
        max = Math.max(max, right);
        el.style.width = orig;
    });
    return Math.ceil(max);
}
