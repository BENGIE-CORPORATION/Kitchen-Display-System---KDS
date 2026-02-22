import 'package:flutter/material.dart';
import '../../../../../utils/constants/colors.dart';

class TMenuItem extends StatefulWidget {
  const TMenuItem({
    super.key,
    required this.route,
    required this.icon,
    required this.itemName,
    required this.isActive,
    required this.onTap,
  });

  final String route;
  final IconData icon;
  final String itemName;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<TMenuItem> createState() => _TMenuItemState();
}

class _TMenuItemState extends State<TMenuItem> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isActive;
    final bool highlighted = active || isHovering;

    return InkWell(
      onTap: widget.onTap,
      onHover: (hovering) {
        setState(() {
          isHovering = hovering;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Container(
          decoration: BoxDecoration(
            color: highlighted ? TColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              Padding(
                padding: const EdgeInsets.only(
                  left: 24,
                  top: 16,
                  bottom: 16,
                  right: 16,
                ),
                child: Icon(
                  widget.icon,
                  size: 22,
                  color: highlighted
                      ? TColors.white
                      : TColors.greyDark,
                ),
              ),

              Flexible(
                child: Text(
                  widget.itemName,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(
                        color: highlighted
                            ? TColors.white
                            : TColors.greyDark,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}